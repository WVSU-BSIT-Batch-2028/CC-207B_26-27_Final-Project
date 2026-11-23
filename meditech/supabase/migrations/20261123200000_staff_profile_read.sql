-- Reliable staff profile reads for pharmacy header + /profile (security definer).

alter table public.staff_members
  add column if not exists avatar_path text;

create or replace function public.get_my_staff_profile()
returns table (
  display_id text,
  first_name text,
  middle_name text,
  last_name text,
  role public.staff_role,
  avatar_path text,
  prc_license_no text,
  prc_license_expiry date,
  license_status public.license_status,
  username text
)
language sql
stable
security definer
set search_path = ''
as $$
  select sm.display_id,
         sm.first_name,
         sm.middle_name,
         sm.last_name,
         sm.role,
         sm.avatar_path,
         sm.prc_license_no,
         sm.prc_license_expiry,
         sm.license_status,
         a.username::text
  from public.staff_members sm
  join public.accounts a on a.id = sm.account_id
  where sm.account_id = auth.uid();
$$;

revoke execute on function public.get_my_staff_profile() from public, anon;
grant execute on function public.get_my_staff_profile() to authenticated;