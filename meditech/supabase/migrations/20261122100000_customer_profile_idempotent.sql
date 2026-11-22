-- Allow finishing customer profile when auth exists but a prior sign-up attempt stopped halfway
create or replace function public.create_customer_profile(
  p_first_name text,
  p_middle_name text,
  p_last_name text,
  p_mobile text,
  p_birthdate date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  user_email text;
  clean_middle text := nullif(btrim(coalesce(p_middle_name, '')), '');
  clean_mobile text := regexp_replace(btrim(p_mobile), '[^0-9]', '', 'g');
begin
  if uid is null then
    raise exception 'You need to sign up before saving your profile.';
  end if;

  if p_birthdate > public.app_today() then
    raise exception 'Birthdate cannot be in the future.';
  end if;

  if clean_mobile !~ '^09[0-9]{9}$' then
    raise exception 'Enter a mobile number like 09171234567.';
  end if;

  if exists (
    select 1 from public.customer_profiles where account_id = uid
  ) then
    return;
  end if;

  if exists (
    select 1 from public.customer_profiles where mobile = clean_mobile
  ) then
    raise exception 'This mobile number is already used.';
  end if;

  select email into user_email from auth.users where id = uid;

  insert into public.accounts (id, account_type, state)
  values (uid, 'customer', 'active')
  on conflict (id) do nothing;

  insert into public.customer_profiles (
    account_id, first_name, middle_name, last_name, mobile, email, birthdate, consent_version
  ) values (
    uid, btrim(p_first_name), clean_middle, btrim(p_last_name),
    clean_mobile, user_email, p_birthdate, 'v1'
  );
end
$$;