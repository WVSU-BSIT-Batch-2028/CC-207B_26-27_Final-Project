-- Possible results of an FDA check
create type public.verification_result as enum
  ('matched', 'not_found', 'details_mismatch', 'expired', 'unreadable');

-- Official websites admins use (only the real FDA portal)
create table public.official_links (
  key text primary key,
  label text not null,
  url text not null check (url like 'https://%'),
  updated_at timestamptz not null default now()
);
insert into public.official_links (key, label, url) values
  ('fda_verification_portal', 'FDA Verification Portal', 'https://verification.fda.gov.ph/');
alter table public.official_links enable row level security;
create policy "Admins read official links" on public.official_links
  for select to authenticated using (public.is_admin());

-- Every FDA check an admin made, kept as history
create table public.verification_checks (
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check (subject_type in ('branch', 'drug_registration')),
  subject_id uuid not null,
  checked_number text not null,              -- the LTO or registration number checked
  checked_details jsonb not null default '{}', -- the details compared, as they were then
  result public.verification_result not null,
  notes text check (notes is null or length(notes) <= 500),
  checked_by uuid not null references public.accounts(id),
  checked_by_label text not null,
  checked_at timestamptz not null default clock_timestamp()
);
create index verification_checks_by_subject
  on public.verification_checks (subject_type, subject_id, checked_at desc);

-- Checks can't be changed or deleted
create trigger verification_checks_locked
  before update or delete on public.verification_checks
  for each row execute function public.block_log_changes();

alter table public.verification_checks enable row level security;
create policy "Admins see checks" on public.verification_checks
  for select to authenticated using (public.is_admin());

-- Record an FDA check on a pharmacy's current LTO details
create or replace function public.record_branch_verification(
  p_branch_id uuid,
  p_result public.verification_result,
  p_notes text default null
)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  b public.branches%rowtype;
  admin_name text;
  new_id uuid;
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into b from public.branches where id = p_branch_id;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  select display_name into admin_name from public.admins where account_id = auth.uid();

  -- Save the check with a copy of the details that were compared
  insert into public.verification_checks
    (subject_type, subject_id, checked_number, checked_details, result, notes, checked_by, checked_by_label)
  values
    ('branch', b.id, b.lto_number,
     jsonb_build_object('pharmacy_name', b.pharmacy_name, 'address', b.address, 'lto_expiry', b.lto_expiry),
     p_result, nullif(trim(p_notes), ''), auth.uid(), admin_name)
  returning id into new_id;

  perform public.log_audit(auth.uid(), admin_name, 'admin', 'admin_action',
    'Recorded FDA check: ' || p_result::text, b.display_id,
    jsonb_build_object('lto_number', b.lto_number));

  return new_id;
end
$$;

-- Is the latest check "matched", and on the pharmacy's current details?
create or replace function public.branch_has_current_match(p_branch_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.branches b
    join lateral (
      select * from public.verification_checks c
      where c.subject_type = 'branch' and c.subject_id = b.id
      order by c.checked_at desc
      limit 1
    ) latest on true
    where b.id = p_branch_id
      and latest.result = 'matched'
      and latest.checked_number = b.lto_number
      and (latest.checked_details ->> 'lto_expiry')::date = b.lto_expiry
      and latest.checked_details ->> 'pharmacy_name' = b.pharmacy_name
      and latest.checked_details ->> 'address' = b.address
  )
$$;

-- Approve a waiting pharmacy
create or replace function public.approve_application(p_branch_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  b public.branches%rowtype;
  admin_name text;
  owner_id uuid;
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  -- Lock the row so two admins can't decide at the same time
  select * into b from public.branches where id = p_branch_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if b.status <> 'pending_approval' then
    raise exception 'NOT_PENDING';
  end if;
  if b.lto_expiry < public.app_today() then
    raise exception 'LTO_EXPIRED';
  end if;
  if not public.branch_has_current_match(b.id) then
    raise exception 'NEEDS_FDA_CHECK';
  end if;

  select display_name into admin_name from public.admins where account_id = auth.uid();
  select account_id into owner_id from public.staff_members where branch_id = b.id and role = 'owner';

  -- The pharmacy goes live and the owner can sign in
  update public.branches set status = 'active', approved_at = now(), rejection_reason = null
  where id = b.id;
  update public.accounts set state = 'active' where id = owner_id;

  -- Tell the owner
  insert into public.notifications (recipient_id, type, title, body)
  values (owner_id, 'application_approved', 'Pharmacy approved',
          b.pharmacy_name || ' is approved. You can now sign in and set up your branch.');

  perform public.log_audit(auth.uid(), admin_name, 'admin', 'pharmacy_application',
    'Approved pharmacy application', b.display_id);
end
$$;

-- Reject a waiting pharmacy, with a reason the owner will see
create or replace function public.reject_application(p_branch_id uuid, p_reason text)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  b public.branches%rowtype;
  admin_name text;
  owner_id uuid;
  reason text := trim(coalesce(p_reason, ''));
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;
  if length(reason) not between 5 and 200 then
    raise exception 'REASON_LENGTH';
  end if;

  select * into b from public.branches where id = p_branch_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if b.status <> 'pending_approval' then
    raise exception 'NOT_PENDING';
  end if;

  select display_name into admin_name from public.admins where account_id = auth.uid();
  select account_id into owner_id from public.staff_members where branch_id = b.id and role = 'owner';

  update public.branches set status = 'rejected', rejection_reason = reason where id = b.id;
  update public.accounts set state = 'rejected' where id = owner_id;

  insert into public.notifications (recipient_id, type, title, body)
  values (owner_id, 'application_rejected', 'Application not approved', reason);

  perform public.log_audit(auth.uid(), admin_name, 'admin', 'pharmacy_application',
    'Rejected pharmacy application', b.display_id, jsonb_build_object('reason', reason));
end
$$;

-- Signed-in users may call these; each one checks for an admin itself
revoke execute on function public.record_branch_verification(uuid, public.verification_result, text) from public, anon;
revoke execute on function public.branch_has_current_match(uuid) from public, anon;
revoke execute on function public.approve_application(uuid) from public, anon;
revoke execute on function public.reject_application(uuid, text) from public, anon;
grant execute on function public.record_branch_verification(uuid, public.verification_result, text) to authenticated;
grant execute on function public.branch_has_current_match(uuid) to authenticated;
grant execute on function public.approve_application(uuid) to authenticated;
grant execute on function public.reject_application(uuid, text) to authenticated;