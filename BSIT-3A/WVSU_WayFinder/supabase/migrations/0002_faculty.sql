begin;

create table if not exists public.faculty (
  id             uuid primary key default gen_random_uuid(),
  full_name      text not null check (btrim(full_name) <> ''),
  department     text,
  college_id     text references public.places(id) on delete set null,
  office_id      text references public.places(id) on delete set null,
  official_email text,
  office_hours   text,

  status         text not null default 'unverified'
                 check (status in ('demo', 'unverified', 'verified')),
  source         text,
  verified_by    text,
  verified_at    timestamptz,

  constraint faculty_verified_requires_source check (
    status <> 'verified'
    or (
      nullif(btrim(source), '') is not null
      and nullif(btrim(verified_by), '') is not null
      and verified_at is not null
    )
  )
);

create index if not exists faculty_name_idx
  on public.faculty (lower(full_name));

create index if not exists faculty_college_idx
  on public.faculty (college_id);

create index if not exists faculty_office_idx
  on public.faculty (office_id);

alter table public.faculty enable row level security;

drop policy if exists "public read verified faculty" on public.faculty;

create policy "public read verified faculty"
  on public.faculty
  for select
  to anon, authenticated
  using (status = 'verified');

-- Expose only student-facing columns through the API.
-- The verifier's identity stays available to authorized maintainers.
revoke all privileges on table public.faculty
  from public, anon, authenticated;

grant select (
  id, full_name, department, college_id, office_id,
  official_email, office_hours, verified_at
) on public.faculty to anon, authenticated;

grant all privileges on table public.faculty to service_role;

commit;