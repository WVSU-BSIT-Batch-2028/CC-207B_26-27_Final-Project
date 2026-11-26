-- Student Process Guide. Students read published + verified guides only.
begin;

create table if not exists public.processes (
  id               text primary key,                 -- e.g. 'proc-enrollment'
  name             text not null,
  summary          text,
  before_you_start text,
  is_published     boolean not null default false,
  status           text not null default 'unverified' check (status in ('demo','unverified','verified')),
  source           text,
  verified_by      text,
  verified_at      timestamptz,
  constraint processes_verified_requires_source check (
    status <> 'verified' or (nullif(btrim(source),'') is not null and nullif(btrim(verified_by),'') is not null and verified_at is not null)
  )
);

create table if not exists public.process_requirements (
  process_id text not null references public.processes(id) on delete cascade,
  position   int  not null,
  kind       text not null check (kind in ('document','note')),
  text       text not null,
  primary key (process_id, position)
);

create table if not exists public.process_steps (
  process_id      text not null references public.processes(id) on delete cascade,
  position        int  not null,
  office_place_id text references public.places(id) on delete set null,
  title           text not null,
  action          text not null,
  primary key (process_id, position)
);

alter table public.processes            enable row level security;
alter table public.process_requirements enable row level security;
alter table public.process_steps        enable row level security;

drop policy if exists "read published verified processes" on public.processes;
create policy "read published verified processes" on public.processes for select to anon, authenticated
  using (is_published and status = 'verified');

drop policy if exists "read requirements of visible processes" on public.process_requirements;
create policy "read requirements of visible processes" on public.process_requirements for select to anon, authenticated
  using (exists (select 1 from public.processes p where p.id = process_id and p.is_published and p.status = 'verified'));

drop policy if exists "read steps of visible processes" on public.process_steps;
create policy "read steps of visible processes" on public.process_steps for select to anon, authenticated
  using (exists (select 1 from public.processes p where p.id = process_id and p.is_published and p.status = 'verified'));

grant select on public.processes, public.process_requirements, public.process_steps to anon, authenticated;
commit;
