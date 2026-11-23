-- Staff profile photos: branch owner uploads for the team (including pharmacists);
-- owners upload their own photo in Settings. Pharmacists cannot self-upload.

alter table public.staff_members
  add column if not exists avatar_path text;

-- Block non-owners from changing their own avatar_path (PRC self-update still allowed).
create or replace function public.guard_staff_avatar_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.avatar_path is distinct from old.avatar_path then
  if public.my_staff_role() is distinct from 'owner' then
      raise exception 'Only the branch owner can set employee profile photos';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists staff_members_guard_avatar on public.staff_members;
create trigger staff_members_guard_avatar
  before update on public.staff_members
  for each row execute function public.guard_staff_avatar_update();

create policy "Owner manages branch staff profiles"
  on public.staff_members
  for update to authenticated
  using (
    branch_id = public.my_branch_id()
    and public.my_staff_role() = 'owner'
  )
  with check (
    branch_id = public.my_branch_id()
    and public.my_staff_role() = 'owner'
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'staff-avatars',
  'staff-avatars',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Object path: {branch_id}/{account_id}/avatar.{ext}
create policy "Owner uploads staff avatars" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'staff-avatars'
    and public.my_staff_role() = 'owner'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
    and exists (
      select 1 from public.staff_members sm
      where sm.branch_id = public.my_branch_id()
        and sm.account_id = ((storage.foldername(name))[2])::uuid
    )
  );

create policy "Owner updates staff avatars" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'staff-avatars'
    and public.my_staff_role() = 'owner'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
  )
  with check (
    bucket_id = 'staff-avatars'
    and public.my_staff_role() = 'owner'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
  );

create policy "Owner deletes staff avatars" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'staff-avatars'
    and public.my_staff_role() = 'owner'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
  );

create policy "Anyone reads staff avatars" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'staff-avatars');

-- Employee list includes avatar_path
drop function if exists public.list_branch_employees();

create or replace function public.list_branch_employees()
returns table (
  account_id uuid,
  display_id text,
  username text,
  role public.staff_role,
  first_name text,
  middle_name text,
  last_name text,
  prc_license_no text,
  prc_license_expiry date,
  license_status public.license_status,
  is_active boolean,
  avatar_path text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if public.my_account_type() <> 'staff' or public.my_staff_role() <> 'owner' then
    raise exception 'Only the pharmacy owner can view the employee list';
  end if;

  return query
  select sm.account_id,
         sm.display_id,
         a.username::text,
         sm.role,
         sm.first_name,
         sm.middle_name,
         sm.last_name,
         sm.prc_license_no,
         sm.prc_license_expiry,
         sm.license_status,
         sm.is_active,
         sm.avatar_path
  from public.staff_members sm
  join public.accounts a on a.id = sm.account_id
  where sm.branch_id = public.my_branch_id()
  order by case sm.role when 'owner' then 0 when 'pharmacist' then 1 else 2 end,
           sm.created_at;
end
$$;

revoke execute on function public.list_branch_employees() from public, anon;
grant execute on function public.list_branch_employees() to authenticated;