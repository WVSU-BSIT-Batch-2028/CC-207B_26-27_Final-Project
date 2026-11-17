-- Returns approved pharmacy branch header details for P-12
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
  distance_km numeric
)
language sql
stable
security definer
set search_path = ''
as $$
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
    end as distance_km
  from public.public_branches b
  where b.id = p_branch_id;
$$;

-- Returns weekly opening hours for an approved branch (0 = Sunday .. 6 = Saturday)
create or replace function public.get_pharmacy_hours(
  p_branch_id uuid
)
returns table (
  weekday smallint,
  opens_at time,
  closes_at time,
  is_closed boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    h.weekday,
    h.opens_at,
    h.closes_at,
    h.is_closed
  from public.public_branch_hours h
  where h.branch_id = p_branch_id
  order by h.weekday asc;
$$;

-- Returns active medicine offerings at one approved branch with optional search query
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
  stock_confirmed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
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
    pa.stock_confirmed_at
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

-- Allow both guests and signed-in customers to view pharmacy details
grant execute on function public.get_pharmacy_details(uuid, numeric, numeric)
  to anon, authenticated;
grant execute on function public.get_pharmacy_hours(uuid)
  to anon, authenticated;
grant execute on function public.get_pharmacy_inventory(uuid, text)
  to anon, authenticated;