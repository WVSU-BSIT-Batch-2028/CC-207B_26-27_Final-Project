-- Search active medicines by brand or generic name with filters and sorting
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
  nearest_km numeric
)
language sql
stable
security definer
set search_path = ''
as $$
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
  -- Calculate straight-line distance in km when customer coordinates are provided
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
  -- Aggregate active pharmacy offers per medicine
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
      -- Rank exact prefix matches ahead of partial matches
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
      and (
        pr.q is null
        or m.brand_name ilike ('%' || pr.q || '%')
        or m.generic_name ilike ('%' || pr.q || '%')
      )
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
    mt.nearest_km
  from matched mt
  cross join params pr
  order by
    case when pr.sort_mode = 'price' then mt.lowest_price end asc nulls last,
    case when pr.sort_mode = 'distance' then mt.nearest_km end asc nulls last,
    case when pr.sort_mode = 'relevance' then mt.relevance_rank end asc,
    mt.brand_name asc,
    mt.strength asc;
$$;

-- Return approved pharmacy offers for one medicine, sorted by price or distance
create or replace function public.get_medicine_offers(
  p_medicine_id uuid,
  p_sort text default 'price',
  p_lat numeric default null,
  p_lng numeric default null
)
returns table (
  inventory_id uuid,
  branch_id uuid,
  branch_display_id text,
  pharmacy_name text,
  branch_name text,
  address text,
  price_per_unit numeric,
  availability public.availability_status,
  stock_confirmed_at timestamptz,
  distance_km numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with calculated as (
    select
      pa.inventory_id,
      b.id as branch_id,
      b.display_id as branch_display_id,
      b.pharmacy_name,
      b.branch_name,
      b.address,
      pa.price_per_unit,
      pa.availability,
      pa.stock_confirmed_at,
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
    from public.public_availability pa
    join public.public_branches b on b.id = pa.branch_id
    where pa.medicine_id = p_medicine_id
  )
  select
    c.inventory_id,
    c.branch_id,
    c.branch_display_id,
    c.pharmacy_name,
    c.branch_name,
    c.address,
    c.price_per_unit,
    c.availability,
    c.stock_confirmed_at,
    c.distance_km
  from calculated c
  order by
    case when p_sort = 'distance' then c.distance_km end asc nulls last,
    c.price_per_unit asc,
    c.pharmacy_name asc;
$$;

-- Allow both guests and signed-in users to search and view offers
grant execute on function public.search_medicines(text, text, text, text, text, numeric, numeric)
  to anon, authenticated;
grant execute on function public.get_medicine_offers(uuid, text, numeric, numeric)
  to anon, authenticated;