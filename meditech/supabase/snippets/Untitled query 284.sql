update public.auth_attempts
set failed_count = 0, locked_until = null
where account_id = (
  select account_id from public.customer_profiles
  where email = 'juan@demo.meditech.dev'
);