-- Let an admin nudge one pharmacy owner before LTO expiry (manual send from the drawer)
create or replace function public.admin_send_lto_reminder(p_branch_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  insert into public.notifications (recipient_id, type, title, body, dedupe_key)
  select s.account_id, 'lto_expiring', 'License to Operate expiring soon',
         b.pharmacy_name || ' – ' || b.branch_name || ': your LTO expires on '
         || to_char(b.lto_expiry, 'Mon DD, YYYY')
         || '. Renew it with the FDA, then update it with the MediTech administrator.',
         'lto_reminder:' || b.id || ':' || b.lto_expiry || ':manual'
  from public.branches b
  join public.staff_members s on s.branch_id = b.id and s.role = 'owner'
  where b.id = p_branch_id
    and b.status = 'active'
  on conflict (dedupe_key) do nothing;

  if not found then
    raise exception 'Branch not found';
  end if;
end;
$$;

revoke execute on function public.admin_send_lto_reminder(uuid) from public, anon;
grant execute on function public.admin_send_lto_reminder(uuid) to authenticated;