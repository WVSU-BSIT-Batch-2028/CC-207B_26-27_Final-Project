-- OpenStreetMap "Not on MediTech" pharmacy listings (Iloilo area)
create type public.osm_listing_status as enum ('shown', 'hidden', 'replaced');

create table public.osm_listings (
  id uuid primary key default gen_random_uuid(),
  osm_id text not null unique,
  name text not null,
  address text not null default 'Iloilo City',
  latitude numeric(9,6) not null,
  longitude numeric(9,6) not null,
  last_edited_there text,
  status public.osm_listing_status not null default 'shown',
  hidden_reason text,
  replaced_by_branch_id uuid references public.branches(id) on delete set null,
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Link pharmacy applications to an existing OpenStreetMap listing if claimed
alter table public.branches
  add column if not exists claimed_osm_listing_id uuid references public.osm_listings(id) on delete set null;

-- Enable row level security immediately
alter table public.osm_listings enable row level security;

-- Guests and patients see active unreplaced listings; admins see all
create policy "Public can read shown osm listings"
  on public.osm_listings
  for select
  to anon, authenticated
  using (status = 'shown' or public.is_admin());

-- Find nearby unreplaced OpenStreetMap listings within a radius (meters)
create or replace function public.find_nearby_osm_listings(
  p_latitude numeric,
  p_longitude numeric,
  p_radius_meters int default 100
)
returns table (
  id uuid,
  osm_id text,
  name text,
  address text,
  latitude numeric,
  longitude numeric,
  distance_meters int
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    o.id,
    o.osm_id,
    o.name,
    o.address,
    o.latitude,
    o.longitude,
    round(
      6371000 * 2 * asin(sqrt(
        power(sin(radians((o.latitude - p_latitude) / 2)), 2) +
        cos(radians(p_latitude)) * cos(radians(o.latitude)) *
        power(sin(radians((o.longitude - p_longitude) / 2)), 2)
      ))
    )::int as distance_meters
  from public.osm_listings o
  where o.status = 'shown'
    and (
      6371000 * 2 * asin(sqrt(
        power(sin(radians((o.latitude - p_latitude) / 2)), 2) +
        cos(radians(p_latitude)) * cos(radians(o.latitude)) *
        power(sin(radians((o.longitude - p_longitude) / 2)), 2)
      ))
    ) <= coalesce(p_radius_meters, 100)
  order by distance_meters asc;
$$;

-- Admin hides an outdated or duplicate OpenStreetMap listing with a reason
create or replace function public.admin_hide_osm_listing(
  p_listing_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := trim(coalesce(p_reason, ''));
  v_listing public.osm_listings%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Only administrators can hide OpenStreetMap listings.';
  end if;

  if length(v_reason) < 5 or length(v_reason) > 200 then
    raise exception 'Reason must be between 5 and 200 characters.';
  end if;

  select * into v_listing
  from public.osm_listings
  where id = p_listing_id
  for update;

  if not found then
    raise exception 'OpenStreetMap listing not found.';
  end if;

  if v_listing.status = 'replaced' then
    raise exception 'Replaced listings cannot be hidden.';
  end if;

  update public.osm_listings
  set status = 'hidden',
      hidden_reason = v_reason
  where id = p_listing_id;

  perform public.log_audit(
    auth.uid(),
    public.my_admin_name(),
    'admin',
    'admin_action',
    'Hid OpenStreetMap listing: ' || v_listing.name,
    v_listing.osm_id,
    jsonb_build_object('reason', v_reason)
  );
end;
$$;

-- Admin restores a hidden OpenStreetMap listing
create or replace function public.admin_show_osm_listing(
  p_listing_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing public.osm_listings%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Only administrators can restore OpenStreetMap listings.';
  end if;

  select * into v_listing
  from public.osm_listings
  where id = p_listing_id
  for update;

  if not found then
    raise exception 'OpenStreetMap listing not found.';
  end if;

  if v_listing.status = 'replaced' then
    raise exception 'Replaced listings cannot be shown again.';
  end if;

  update public.osm_listings
  set status = 'shown',
      hidden_reason = null
  where id = p_listing_id;

  perform public.log_audit(
    auth.uid(),
    public.my_admin_name(),
    'admin',
    'admin_action',
    'Restored OpenStreetMap listing: ' || v_listing.name,
    v_listing.osm_id
  );
end;
$$;

-- Automatically replace a claimed OpenStreetMap listing when its pharmacy is approved
create or replace function public.replace_claimed_osm_listing_on_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'active'
     and old.status is distinct from 'active'
     and new.claimed_osm_listing_id is not null then
    update public.osm_listings
    set status = 'replaced',
        replaced_by_branch_id = new.id,
        hidden_reason = null
    where id = new.claimed_osm_listing_id
      and status <> 'replaced';
  end if;
  return new;
end;
$$;

create trigger trg_replace_claimed_osm_listing
  after update of status on public.branches
  for each row
  execute function public.replace_claimed_osm_listing_on_approval();

-- Permissions
revoke execute on function public.find_nearby_osm_listings(numeric, numeric, int) from public;
grant execute on function public.find_nearby_osm_listings(numeric, numeric, int) to anon, authenticated;

revoke execute on function public.admin_hide_osm_listing(uuid, text) from public, anon;
grant execute on function public.admin_hide_osm_listing(uuid, text) to authenticated;

revoke execute on function public.admin_show_osm_listing(uuid) from public, anon;
grant execute on function public.admin_show_osm_listing(uuid) to authenticated;