-- Let customers sign in after email confirmation even before create_customer_profile ran.
create or replace function public.find_account_for_sign_in(p_identifier text)
returns table (account_id uuid, email text, account_type public.account_type, display_name text)
language sql stable security definer
set search_path = ''
as $$
  select *
  from (
    select a.id,
           u.email::text,
           a.account_type,
           coalesce(cp.first_name || ' ' || cp.last_name,
                    sm.first_name || ' ' || sm.last_name,
                    ad.display_name,
                    u.email::text) as display_name
    from public.accounts a
    join auth.users u on u.id = a.id
    left join public.customer_profiles cp on cp.account_id = a.id
    left join public.staff_members sm on sm.account_id = a.id
    left join public.admins ad on ad.account_id = a.id
    where lower(u.email) = lower(trim(p_identifier))
       or cp.mobile = trim(p_identifier)
       or lower(a.username::text) = lower(trim(p_identifier))

    union all

    select u.id,
           u.email::text,
           'customer'::public.account_type,
           u.email::text
    from auth.users u
    where lower(u.email) = lower(trim(p_identifier))
      and not exists (select 1 from public.accounts a where a.id = u.id)
  ) matches
  limit 1;
$$;

revoke execute on function public.find_account_for_sign_in(text) from public, anon, authenticated;
grant execute on function public.find_account_for_sign_in(text) to service_role;