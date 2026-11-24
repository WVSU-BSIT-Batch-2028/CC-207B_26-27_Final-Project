-- Pharmacy storefront photos (customer-facing) and catalogue medicine images.

alter table public.medicines
  add column if not exists image_path text;

-- Public bucket for medicine pack shots (stable URLs for customer app).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'medicine-images',
  'medicine-images',
  true,
  3145728,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Admins manage medicine images" on storage.objects;
create policy "Admins manage medicine images" on storage.objects
  for all to authenticated
  using (bucket_id = 'medicine-images' and public.is_admin())
  with check (bucket_id = 'medicine-images' and public.is_admin());

-- Approved-branch storefront JPEG/PNG: readable by guests via signed URL (storage RLS).
drop policy if exists "Customers read approved storefront photos" on storage.objects;
create policy "Customers read approved storefront photos" on storage.objects
  for select to anon, authenticated
  using (
    bucket_id = 'pharmacy-documents'
    and exists (
      select 1
      from public.branch_documents d
      join public.public_branches b on b.id = d.branch_id
      where d.kind = 'storefront'
        and d.mime_type like 'image/%'
        and d.storage_path = name
    )
  );

-- Owner may upload a new storefront for an active branch.
drop policy if exists "Owner uploads branch storefront" on storage.objects;
create policy "Owner uploads branch storefront" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'pharmacy-documents'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
    and (storage.foldername(name))[2] = 'storefront'
    and public.my_staff_role() = 'owner'
  );

drop policy if exists "Owner updates branch storefront" on storage.objects;
create policy "Owner updates branch storefront" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'pharmacy-documents'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
    and public.my_staff_role() = 'owner'
  );

create or replace function public.owner_update_storefront(
  p_path text,
  p_mime text,
  p_size int
)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  bid uuid;
begin
  if public.my_staff_role() <> 'owner' then
    raise exception 'NOT_ALLOWED';
  end if;
  bid := public.my_branch_id();
  if bid is null then
    raise exception 'NO_BRANCH';
  end if;
  if p_mime not in ('image/jpeg', 'image/png', 'image/webp') then
    raise exception 'BAD_MIME';
  end if;
  if p_size < 1 or p_size > 5242880 then
    raise exception 'BAD_SIZE';
  end if;

  insert into public.branch_documents (branch_id, kind, storage_path, mime_type, size_bytes, uploaded_by)
  values (bid, 'storefront', p_path, p_mime, p_size, auth.uid());
end
$$;

revoke all on function public.owner_update_storefront(text, text, int) from public;
grant execute on function public.owner_update_storefront(text, text, int) to authenticated;

-- Catalogue save: optional image_path
create or replace function public.admin_save_medicine(p jsonb)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  med_id uuid := (p->>'id')::uuid;
  reg public.drug_registrations%rowtype;
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into reg from public.drug_registrations where id = (p->>'registration_id')::uuid;
  if not found then
    raise exception 'NEEDS_REGISTRATION';
  end if;

  if med_id is null then
    insert into public.medicines
      (registration_id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id,
       pack_description, is_rx, status, image_path)
    values
      (reg.id, coalesce(nullif(trim(p->>'brand_name'), ''), reg.brand_name, reg.generic_name),
       reg.generic_name, reg.strength, reg.dosage_form_id, (p->>'unit_sold_id')::smallint,
       nullif(trim(p->>'pack_description'), ''), reg.is_rx, 'draft',
       nullif(trim(p->>'image_path'), ''))
    returning id into med_id;
  else
    update public.medicines set
      registration_id = reg.id,
      brand_name = coalesce(nullif(trim(p->>'brand_name'), ''), reg.brand_name, reg.generic_name),
      generic_name = reg.generic_name,
      strength = reg.strength,
      dosage_form_id = reg.dosage_form_id,
      unit_sold_id = (p->>'unit_sold_id')::smallint,
      pack_description = nullif(trim(p->>'pack_description'), ''),
      is_rx = reg.is_rx,
      image_path = case
        when p ? 'image_path' then nullif(trim(p->>'image_path'), '')
        else image_path
      end
    where id = med_id;
  end if;

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    'Saved catalogue medicine', med_id::text);
  return med_id;
end
$$;

drop function if exists public.admin_list_medicines(public.medicine_status, text);

create or replace function public.admin_list_medicines(
  p_status public.medicine_status default null,
  p_search text default null
)
returns table (
  id uuid,
  display_id text,
  brand_name text,
  generic_name text,
  strength text,
  dosage_form text,
  unit_sold text,
  pack_description text,
  is_rx boolean,
  status public.medicine_status,
  registration_id uuid,
  registration_number text,
  fda_matched boolean,
  pharmacies_stocking bigint,
  image_path text
)
language sql stable security definer
set search_path = ''
as $$
  select m.id, m.display_id, m.brand_name, m.generic_name, m.strength,
         f.name, u.name, m.pack_description, m.is_rx, m.status,
         r.id, r.registration_number,
         coalesce(public.registration_has_current_match(r.id), false),
         (select count(*) from public.inventory_items i where i.medicine_id = m.id and i.is_active),
         m.image_path
  from public.medicines m
  join public.dosage_forms f on f.id = m.dosage_form_id
  join public.units u on u.id = m.unit_sold_id
  left join public.drug_registrations r on r.id = m.registration_id
  where public.is_admin()
    and (p_status is null or m.status = p_status)
    and (coalesce(p_search, '') = ''
         or m.brand_name ilike '%' || p_search || '%'
         or m.generic_name ilike '%' || p_search || '%'
         or m.display_id ilike '%' || p_search || '%'
         or r.registration_number ilike '%' || p_search || '%')
  order by m.generic_name, m.brand_name, m.strength
$$;

revoke execute on function public.admin_list_medicines(public.medicine_status, text) from public, anon;
grant execute on function public.admin_list_medicines(public.medicine_status, text) to authenticated;

drop function if exists public.get_pharmacy_details(uuid, numeric, numeric);
create or replace function public.get_pharmacy_details(
  p_branch_id uuid,
  p_lat numeric default null,
  p_lng numeric default null
)
returns table (
  branch_id uuid,
  display_id text,
  pharmacy_name text,
  branch_name text,
  address text,
  contact_number text,
  latitude numeric,
  longitude numeric,
  distance_km numeric,
  storefront_path text
)
language sql stable security definer set search_path = '' as $$
  select
    b.id as branch_id,
    b.display_id,
    b.pharmacy_name,
    b.branch_name,
    b.address,
    b.contact_number,
    b.latitude,
    b.longitude,
    case
      when p_lat is not null and p_lng is not null then
        round(
          (
            6371 * acos(
              least(
                1.0,
                greatest(
                  -1.0,
                  cos(radians(p_lat)) * cos(radians(b.latitude))
                  * cos(radians(b.longitude) - radians(p_lng))
                  + sin(radians(p_lat)) * sin(radians(b.latitude))
                )
              )
            )
          )::numeric,
          2
        )
      else null
    end as distance_km,
  (
    select d.storage_path
    from public.branch_documents d
    where d.branch_id = b.id
      and d.kind = 'storefront'
      and d.mime_type like 'image/%'
    order by d.uploaded_at desc
    limit 1
  ) as storefront_path
  from public.public_branches b
  where b.id = p_branch_id;
$$;

grant execute on function public.get_pharmacy_details(uuid, numeric, numeric) to anon, authenticated;

drop function if exists public.get_pharmacy_inventory(uuid, text);
create or replace function public.get_pharmacy_inventory(
  p_branch_id uuid,
  p_query text default null
)
returns table (
  inventory_id uuid,
  medicine_id uuid,
  medicine_display_id text,
  brand_name text,
  generic_name text,
  strength text,
  dosage_form text,
  unit_sold text,
  pack_description text,
  is_rx boolean,
  price_per_unit numeric,
  availability public.availability_status,
  stock_confirmed_at timestamptz,
  image_path text
)
language sql stable security definer set search_path = '' as $$
  with params as (
    select nullif(trim(coalesce(p_query, '')), '') as q
  )
  select
    pa.inventory_id,
    m.id as medicine_id,
    m.display_id as medicine_display_id,
    m.brand_name,
    m.generic_name,
    m.strength,
    df.name as dosage_form,
    u.name as unit_sold,
    m.pack_description,
    m.is_rx,
    pa.price_per_unit,
    pa.availability,
    pa.stock_confirmed_at,
    m.image_path
  from public.public_availability pa
  join public.medicines m on m.id = pa.medicine_id
  join public.dosage_forms df on df.id = m.dosage_form_id
  join public.units u on u.id = m.unit_sold_id
  cross join params pr
  where pa.branch_id = p_branch_id
    and (
      pr.q is null
      or m.brand_name ilike ('%' || pr.q || '%')
      or m.generic_name ilike ('%' || pr.q || '%')
    )
  order by m.brand_name asc, m.strength asc;
$$;

grant execute on function public.get_pharmacy_inventory(uuid, text) to anon, authenticated;

drop function if exists public.search_medicines(text, text, text, text, text, numeric, numeric);
create or replace function public.search_medicines(
  p_query text default null,
  p_strength text default null,
  p_dosage_form text default null,
  p_location text default null,
  p_sort text default 'relevance',
  p_lat numeric default null,
  p_lng numeric default null
)
returns table (
  medicine_id uuid,
  display_id text,
  brand_name text,
  generic_name text,
  strength text,
  dosage_form text,
  unit_sold text,
  is_rx boolean,
  lowest_price numeric,
  pharmacy_count bigint,
  nearest_km numeric,
  image_path text
)
language sql stable security definer set search_path = '' as $$
  with params as (
    select
      nullif(trim(coalesce(p_query, '')), '') as q,
      nullif(trim(coalesce(p_strength, '')), '') as strength_filter,
      nullif(trim(coalesce(p_dosage_form, '')), '') as form_filter,
      nullif(trim(coalesce(p_location, '')), '') as location_filter,
      case
        when p_sort in ('relevance', 'price', 'distance') then p_sort
        else 'relevance'
      end as sort_mode
  ),
  branch_distances as (
    select
      b.id,
      b.address,
      case
        when p_lat is not null and p_lng is not null then
          round(
            (
              6371 * acos(
                least(
                  1.0,
                  greatest(
                    -1.0,
                    cos(radians(p_lat)) * cos(radians(b.latitude))
                    * cos(radians(b.longitude) - radians(p_lng))
                    + sin(radians(p_lat)) * sin(radians(b.latitude))
                  )
                )
              )
            )::numeric,
            2
          )
        else null
      end as distance_km
    from public.public_branches b
  ),
  offers as (
    select
      pa.medicine_id,
      min(pa.price_per_unit) as lowest_price,
      count(distinct pa.branch_id) as pharmacy_count,
      min(bd.distance_km) as nearest_km
    from public.public_availability pa
    join branch_distances bd on bd.id = pa.branch_id
    cross join params pr
    where pr.location_filter is null
      or bd.address ilike ('%' || pr.location_filter || '%')
    group by pa.medicine_id
  ),
  matched as (
    select
      m.id as medicine_id,
      m.display_id,
      m.brand_name,
      m.generic_name,
      m.strength,
      df.name as dosage_form,
      u.name as unit_sold,
      m.is_rx,
      o.lowest_price,
      o.pharmacy_count,
      o.nearest_km,
      m.image_path,
      case
        when pr.q is null then 2
        when m.brand_name ilike (pr.q || '%') or m.generic_name ilike (pr.q || '%') then 0
        else 1
      end as relevance_rank
    from public.medicines m
    join public.dosage_forms df on df.id = m.dosage_form_id
    join public.units u on u.id = m.unit_sold_id
    join offers o on o.medicine_id = m.id
    cross join params pr
    where m.status = 'active'
      and (pr.q is null
           or m.brand_name ilike ('%' || pr.q || '%')
           or m.generic_name ilike ('%' || pr.q || '%'))
      and (pr.strength_filter is null or m.strength ilike pr.strength_filter)
      and (pr.form_filter is null or df.name ilike pr.form_filter)
  )
  select
    mt.medicine_id,
    mt.display_id,
    mt.brand_name,
    mt.generic_name,
    mt.strength,
    mt.dosage_form,
    mt.unit_sold,
    mt.is_rx,
    mt.lowest_price,
    mt.pharmacy_count,
    mt.nearest_km,
    mt.image_path
  from matched mt
  cross join params pr
  order by
    case when pr.sort_mode = 'price' then mt.lowest_price end asc nulls last,
    case when pr.sort_mode = 'distance' then mt.nearest_km end asc nulls last,
    case when pr.sort_mode = 'relevance' then mt.relevance_rank end asc,
    mt.brand_name asc,
    mt.strength asc;
$$;

grant execute on function public.search_medicines(text, text, text, text, text, numeric, numeric)
  to anon, authenticated;