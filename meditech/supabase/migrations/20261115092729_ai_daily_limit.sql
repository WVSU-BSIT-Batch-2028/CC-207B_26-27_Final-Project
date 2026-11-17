-- Count assistant questions per customer, in Philippine time. The limit is 20 a day.
create table public.ai_daily_usage (
  account_id uuid not null references public.accounts(id) on delete cascade,
  used_on date not null,
  message_count int not null default 0 check (message_count >= 0),
  primary key (account_id, used_on)
);

alter table public.ai_daily_usage enable row level security;

create or replace function public.consume_ai_message(p_account_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_count int;
begin
  insert into public.ai_daily_usage (account_id, used_on, message_count)
  values (p_account_id, public.app_today(), 1)
  on conflict (account_id, used_on)
  do update set message_count = public.ai_daily_usage.message_count + 1
  where public.ai_daily_usage.message_count < 20
  returning message_count into next_count;

  return next_count is not null;
end
$$;

revoke all on function public.consume_ai_message(uuid) from public, anon, authenticated;
grant execute on function public.consume_ai_message(uuid) to service_role;