-- Every pharmacy user can edit their own name and profile photo.
-- Owners can still set photos for other people on the team.

alter table public.staff_members
  add column if not exists avatar_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'staff-avatars',
  'staff-avatars',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = 2097152,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

create or replace function public.guard_staff_avatar_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.avatar_path is not distinct from old.avatar_path then
    return new;
  end if;

  -- Anyone may change their own photo.
  if auth.uid() = old.account_id then
    return new;
  end if;

  -- Owners may set photos for people in their branch.
  if public.my_staff_role() = 'owner'
     and old.branch_id = public.my_branch_id() then
    return new;
  end if;

  raise exception 'You can only change your own profile photo';
end;
$$;

-- Own folder: {branch_id}/{account_id}/avatar.ext
drop policy if exists "Staff uploads own avatar" on storage.objects;
create policy "Staff uploads own avatar" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'staff-avatars'
    and public.my_account_type() = 'staff'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "Staff updates own avatar" on storage.objects;
create policy "Staff updates own avatar" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'staff-avatars'
    and (storage.foldername(name))[2] = auth.uid()::text
    and (storage.foldername(name))[1] = public.my_branch_id()::text
  )
  with check (
    bucket_id = 'staff-avatars'
    and (storage.foldername(name))[2] = auth.uid()::text
    and (storage.foldername(name))[1] = public.my_branch_id()::text
  );

drop policy if exists "Staff deletes own avatar" on storage.objects;
create policy "Staff deletes own avatar" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'staff-avatars'
    and (storage.foldername(name))[2] = auth.uid()::text
    and (storage.foldername(name))[1] = public.my_branch_id()::text
  );

create or replace function public.update_my_staff_profile(
  p_first_name text,
  p_middle_name text,
  p_last_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_middle text := nullif(trim(p_middle_name), '');
begin
  if auth.uid() is null or public.my_account_type() <> 'staff' then
    raise exception 'Sign in as pharmacy staff to edit your profile';
  end if;

  if p_first_name is null or p_first_name !~ '^[A-Za-zÑñ .''-]{2,50}$' then
    raise exception 'First name: 2 to 50 letters';
  end if;
  if p_last_name is null or p_last_name !~ '^[A-Za-zÑñ .''-]{2,50}$' then
    raise exception 'Last name: 2 to 50 letters';
  end if;
  if v_middle is not null and v_middle !~ '^[A-Za-zÑñ .''-]{2,50}$' then
    raise exception 'Middle name: 2 to 50 letters';
  end if;

  update public.staff_members
  set first_name = trim(p_first_name),
      middle_name = v_middle,
      last_name = trim(p_last_name)
  where account_id = auth.uid();

  if not found then
    raise exception 'Profile not found';
  end if;
end;
$$;

revoke execute on function public.update_my_staff_profile(text, text, text) from public, anon;
grant execute on function public.update_my_staff_profile(text, text, text) to authenticated;
