-- My Schedule (private). Each student sees and changes only their own rows/files.
-- Requires Supabase Auth (signed-in users). Until sign-in exists in the apps, schedules are kept
-- on the student's own device only (see app code); this migration is ready for cloud sync.
begin;

create table if not exists public.schedule_uploads (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade default auth.uid(),
  storage_path text not null,                     -- schedule-images/{user_id}/{uuid}.jpg
  uploaded_at  timestamptz not null default now()
);

create table if not exists public.class_sessions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade default auth.uid(),
  upload_id       uuid references public.schedule_uploads(id) on delete set null,
  subject         text not null check (btrim(subject) <> ''),
  weekday         int  not null check (weekday between 1 and 7),   -- 1 = Monday ... 7 = Sunday
  start_time      time not null,
  end_time        time not null check (end_time > start_time),
  tz              text not null default 'Asia/Manila' check (tz = 'Asia/Manila'),
  room_code_raw   text not null,                                    -- exactly what the student typed
  room_place_id   text references public.places(id) on delete set null, -- null = location unconfirmed
  professor_name  text,
  remind_minutes  int  check (remind_minutes is null or remind_minutes between 0 and 240),
  updated_at      timestamptz not null default now()
);
create index if not exists class_sessions_user_idx on public.class_sessions(user_id);

alter table public.schedule_uploads enable row level security;
alter table public.class_sessions  enable row level security;

drop policy if exists "own uploads" on public.schedule_uploads;
create policy "own uploads" on public.schedule_uploads for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own classes" on public.class_sessions;
create policy "own classes" on public.class_sessions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on public.schedule_uploads, public.class_sessions from anon;
grant select, insert, update, delete on public.schedule_uploads, public.class_sessions to authenticated;

-- Private bucket: files live under a folder named after the owner's user id.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('schedule-images', 'schedule-images', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "own schedule images" on storage.objects;
create policy "own schedule images" on storage.objects for all to authenticated
  using (bucket_id = 'schedule-images' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'schedule-images' and (storage.foldername(name))[1] = auth.uid()::text);

commit;
