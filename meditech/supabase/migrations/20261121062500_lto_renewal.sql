-- ===== 1. Owner suspended while the pharmacy is offline =====

-- React to a pharmacy going offline or coming back
create or replace function public.on_branch_status_change()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  select account_id into owner_id
  from public.staff_members where branch_id = new.id and role = 'owner';
  if owner_id is null then
    return new;
  end if;

  -- Taken offline: the owner can only renew their license until it's back
  if old.status = 'active' and new.status = 'inactive' then
    update public.accounts set state = 'suspended' where id = owner_id;
    insert into public.notifications (recipient_id, type, title, body)
    values (owner_id, 'branch_deactivated', 'Pharmacy deactivated',
            new.pharmacy_name || ' is offline. Reason: '
            || coalesce(new.deactivation_reason, 'not given')
            || '. You can upload a renewed License to Operate from your account.');

  -- Back online: the owner gets full access again
  elsif old.status = 'inactive' and new.status = 'active' then
    update public.accounts set state = 'active' where id = owner_id and state = 'suspended';
    insert into public.notifications (recipient_id, type, title, body)
    values (owner_id, 'branch_activated', 'Pharmacy back online',
            new.pharmacy_name || ' is visible to customers again.');
  end if;

  return new;
end
$$;

create trigger branch_status_change
  after update of status on public.branches
  for each row when (old.status is distinct from new.status)
  execute function public.on_branch_status_change();

-- Sign-in check: staff of an offline pharmacy can't sign in (the owner can, to renew)
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  uid uuid := (event->>'user_id')::uuid;
  claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  acc record;
  staff record;
begin
  select account_type, state into acc from public.accounts where id = uid;

  -- Deactivated accounts can't sign in
  if acc.state = 'deactivated' then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 403, 'message', 'This account has been deactivated.'));
  end if;

  -- Locked accounts wait 15 minutes
  if exists (select 1 from public.auth_attempts
             where account_id = uid and locked_until > now()) then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 429, 'message', 'Too many wrong passwords. Try again in 15 minutes.'));
  end if;

  select s.branch_id, s.role, b.status as branch_status into staff
  from public.staff_members s
  join public.branches b on b.id = s.branch_id
  where s.account_id = uid and s.is_active;

  -- Staff of an offline pharmacy can't sign in; the owner still can
  if staff.branch_status = 'inactive' and staff.role <> 'owner' then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 403, 'message', 'This pharmacy is offline. Contact your pharmacy owner.'));
  end if;

  -- Add role details so the app knows where to send the user
  claims := claims
    || jsonb_build_object('app_account_type', acc.account_type)
    || jsonb_build_object('app_state', acc.state)
    || jsonb_build_object('app_role', staff.role)
    || jsonb_build_object('app_branch_id', staff.branch_id);

  return jsonb_set(event, '{claims}', claims);
end
$$;

-- ===== 2. Renewed licenses sent by suspended owners =====

-- Where a renewal stands
create type public.renewal_status as enum ('pending', 'accepted', 'rejected');

create table public.lto_renewals (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  lto_number text not null check (length(trim(lto_number)) between 3 and 40),
  lto_expiry date not null,
  storage_path text not null,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'application/pdf')),
  size_bytes int not null check (size_bytes between 1 and 5242880),
  status public.renewal_status not null default 'pending',
  review_reason text check (review_reason is null or length(review_reason) between 5 and 200),
  submitted_by uuid not null references public.accounts(id),
  reviewed_by uuid references public.accounts(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Only one renewal waiting per pharmacy
create unique index one_pending_renewal on public.lto_renewals (branch_id) where status = 'pending';

-- The owner sees their own renewals; admins see all
alter table public.lto_renewals enable row level security;
create policy "Owner sees own renewals" on public.lto_renewals
  for select to authenticated
  using (branch_id = public.my_branch_id() and public.my_staff_role() = 'owner');
create policy "Admins see renewals" on public.lto_renewals
  for select to authenticated using (public.is_admin());

-- A suspended owner may upload the renewed LTO into their own folder
create policy "Owner uploads renewal while offline" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'pharmacy-documents'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
    and public.my_staff_role() = 'owner'
    and exists (select 1 from public.branches b
                where b.id = public.my_branch_id() and b.status = 'inactive')
  );

-- The owner sends a renewed LTO
create or replace function public.submit_lto_renewal(p jsonb)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  my_branch uuid := public.my_branch_id();
  b public.branches%rowtype;
  owner_name text;
  new_id uuid;
begin
  -- Only the owner of an offline pharmacy can renew
  if my_branch is null or public.my_staff_role() is distinct from 'owner' then
    raise exception 'NOT_ALLOWED';
  end if;
  select * into b from public.branches where id = my_branch;
  if b.status <> 'inactive' then
    raise exception 'NOT_INACTIVE';
  end if;

  -- The new license must still be valid, and the file in this pharmacy's folder
  if (p->>'lto_expiry')::date < public.app_today() then
    raise exception 'LTO_EXPIRED';
  end if;
  if split_part(p->>'storage_path', '/', 1) <> my_branch::text then
    raise exception 'BAD_DOCUMENT_PATH';
  end if;

  select first_name || ' ' || last_name into owner_name
  from public.staff_members where account_id = auth.uid();

  insert into public.lto_renewals
    (branch_id, lto_number, lto_expiry, storage_path, mime_type, size_bytes, submitted_by)
  values
    (my_branch, trim(p->>'lto_number'), (p->>'lto_expiry')::date, p->>'storage_path',
     p->>'mime_type', (p->>'size_bytes')::int, auth.uid())
  returning id into new_id;

  -- Let every admin know
  insert into public.notifications (recipient_id, type, title, body)
  select a.account_id, 'lto_renewal', 'Renewed LTO received',
         b.pharmacy_name || ' – ' || b.branch_name || ' sent a renewed License to Operate.'
  from public.admins a where a.is_active;

  perform public.log_audit(auth.uid(), owner_name, 'owner', 'pharmacy_application',
    'Sent a renewed LTO', b.display_id);
  return new_id;
end
$$;

-- The admin accepts or rejects a renewed LTO
create or replace function public.review_lto_renewal(
  p_renewal_id uuid,
  p_accept boolean,
  p_reason text default null
)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  r public.lto_renewals%rowtype;
  b public.branches%rowtype;
  reason text := trim(coalesce(p_reason, ''));
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into r from public.lto_renewals where id = p_renewal_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if r.status <> 'pending' then
    raise exception 'NOT_PENDING';
  end if;
  select * into b from public.branches where id = r.branch_id;

  if p_accept then
    -- The pharmacy now carries the renewed license details
    update public.branches set lto_number = r.lto_number, lto_expiry = r.lto_expiry
    where id = r.branch_id;
    insert into public.branch_documents (branch_id, kind, storage_path, mime_type, size_bytes, uploaded_by)
    values (r.branch_id, 'lto_renewal', r.storage_path, r.mime_type, r.size_bytes, r.submitted_by);
    update public.lto_renewals set status = 'accepted', reviewed_by = auth.uid(), reviewed_at = now()
    where id = r.id;

    insert into public.notifications (recipient_id, type, title, body)
    values (r.submitted_by, 'lto_renewal_accepted', 'Renewed LTO accepted',
            'The administrator will check it with the FDA and reactivate your pharmacy.');
  else
    if length(reason) not between 5 and 200 then
      raise exception 'REASON_LENGTH';
    end if;
    update public.lto_renewals
    set status = 'rejected', review_reason = reason, reviewed_by = auth.uid(), reviewed_at = now()
    where id = r.id;

    insert into public.notifications (recipient_id, type, title, body)
    values (r.submitted_by, 'lto_renewal_rejected', 'Renewed LTO not accepted', reason);
  end if;

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    case when p_accept then 'Accepted renewed LTO' else 'Rejected renewed LTO' end,
    b.display_id,
    case when p_accept then '{}'::jsonb else jsonb_build_object('reason', reason) end);
end
$$;

-- ===== 3. Reminder before an LTO expires =====

-- Remind owners 30 days ahead (once per license; returns how many were sent)
create or replace function public.send_lto_expiry_reminders()
returns int
language plpgsql security definer
set search_path = ''
as $$
declare
  sent int;
begin
  insert into public.notifications (recipient_id, type, title, body, dedupe_key)
  select s.account_id, 'lto_expiring', 'License to Operate expiring soon',
         b.pharmacy_name || ' – ' || b.branch_name || ': your LTO expires on '
         || to_char(b.lto_expiry, 'Mon DD, YYYY')
         || '. Renew it with the FDA, then update it with the MediTech administrator.',
         'lto_reminder:' || b.id || ':' || b.lto_expiry
  from public.branches b
  join public.staff_members s on s.branch_id = b.id and s.role = 'owner'
  where b.status = 'active'
    and b.lto_expiry between public.app_today() and public.app_today() + 30
  on conflict (dedupe_key) do nothing;

  get diagnostics sent = row_count;
  return sent;
end
$$;

-- Run it every morning at 8 AM Philippine time (midnight UTC)
create extension if not exists pg_cron;
select cron.schedule('lto-expiry-reminders', '0 0 * * *', $$select public.send_lto_expiry_reminders()$$);

-- Who may call what
revoke execute on function public.submit_lto_renewal(jsonb) from public, anon;
revoke execute on function public.review_lto_renewal(uuid, boolean, text) from public, anon;
revoke execute on function public.send_lto_expiry_reminders() from public, anon, authenticated;
grant execute on function public.submit_lto_renewal(jsonb) to authenticated;
grant execute on function public.review_lto_renewal(uuid, boolean, text) to authenticated;