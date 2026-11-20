-- Entrances, verified walkways and floor plans for the Campus Map. Routes use VERIFIED rows only.
begin;

create table if not exists public.walk_nodes (
  id     text primary key,
  lng    double precision not null,
  lat    double precision not null,
  status text not null default 'unverified' check (status in ('demo','unverified','verified'))
);

create table if not exists public.walk_edges (
  id        text primary key,
  from_node text not null references public.walk_nodes(id) on delete cascade,
  to_node   text not null references public.walk_nodes(id) on delete cascade,
  length_m  double precision check (length_m is null or length_m > 0),  -- null = computed from coordinates
  status    text not null default 'unverified' check (status in ('demo','unverified','verified'))
);

create table if not exists public.entrances (
  id          text primary key,
  building_id text not null references public.places(id) on delete cascade,
  name        text not null,
  lng         double precision not null,
  lat         double precision not null,
  node_id     text references public.walk_nodes(id) on delete set null,
  status      text not null default 'unverified' check (status in ('demo','unverified','verified'))
);

create table if not exists public.floor_plans (
  id          text primary key,
  building_id text not null references public.places(id) on delete cascade,
  floor       int not null,
  label       text,
  image_url   text not null,                -- public URL (e.g. a public 'floor-plans' storage bucket)
  status      text not null default 'unverified' check (status in ('demo','unverified','verified'))
);

do $$ declare t text; begin
  foreach t in array array['walk_nodes','walk_edges','entrances','floor_plans'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "read verified" on public.%I', t);
    execute format('create policy "read verified" on public.%I for select to anon, authenticated using (status = ''verified'')', t);
    execute format('grant select on public.%I to anon, authenticated', t);
  end loop;
end $$;
commit;
