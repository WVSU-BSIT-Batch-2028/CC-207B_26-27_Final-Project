-- Shared place IDs: buildings, rooms, offices, colleges, landmarks.
create table if not exists public.places (
  id          text primary key,                       -- e.g. 'bldg-cb', 'room-cb-203'
  kind        text not null check (kind in ('building','room','office','college','landmark')),
  name        text not null,
  short_name  text,
  room_code   text unique,                            -- normalized: upper-case, no spaces/dashes (CB203)
  floor       int,
  parent_id   text references public.places(id),      -- room -> building
  lng         double precision,
  lat         double precision,
  status      text not null default 'unverified' check (status in ('demo','unverified','verified')),
  source      text,
  verified_by text,
  verified_at timestamptz
);

create index if not exists places_parent_idx on public.places(parent_id);
create index if not exists places_name_idx on public.places (lower(name));

alter table public.places enable row level security;

-- Public clients (anon key) may read VERIFIED rows only.
drop policy if exists "public read verified places" on public.places;
create policy "public read verified places" on public.places
  for select to anon, authenticated using (status = 'verified');

-- No insert/update/delete policies: writes go through the dashboard / service role until the editor role exists.
