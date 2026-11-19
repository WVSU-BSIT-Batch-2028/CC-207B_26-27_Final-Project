-- Number counter for request IDs
create sequence public.request_display_seq;

-- Where a request stands
create type public.request_status as enum ('open', 'added', 'dismissed');

-- A pharmacy asking for a medicine that isn't in the catalogue yet
create table public.medicine_requests (
  id uuid primary key default gen_random_uuid(),
  display_id text not null unique
    default ('REQ-' || lpad(nextval('public.request_display_seq')::text, 6, '0')),
  branch_id uuid not null references public.branches(id),
  requested_by uuid not null references public.accounts(id),
  requested_by_label text not null,
  generic_name text not null check (length(trim(generic_name)) between 2 and 100),
  brand_name text check (brand_name is null or length(brand_name) <= 100),
  strength text check (strength is null or length(strength) <= 50),
  dosage_form text check (dosage_form is null or length(dosage_form) <= 50),
  registration_number text check (registration_number is null or length(registration_number) <= 50),
  notes text check (notes is null or length(notes) <= 500),
  status public.request_status not null default 'open',
  dismiss_reason text check (dismiss_reason is null or length(dismiss_reason) between 5 and 200),
  resolved_medicine_id uuid references public.medicines(id),
  resolved_by uuid references public.accounts(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index medicine_requests_by_status on public.medicine_requests (status, created_at desc);
create index medicine_requests_by_branch on public.medicine_requests (branch_id, created_at desc);

-- Staff see their own branch's requests; admins see all
alter table public.medicine_requests enable row level security;
create policy "Own branch requests" on public.medicine_requests
  for select to authenticated using (branch_id = public.my_branch_id());
create policy "Admins see requests" on public.medicine_requests
  for select to authenticated using (public.is_admin());

-- A pharmacy sends a request
create or replace function public.submit_medicine_request(p jsonb)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  my_branch uuid := public.my_branch_id();
  staff_name text;
  new_display_id text;
begin
  -- Only staff of an approved pharmacy can request
  if my_branch is null
     or not exists (select 1 from public.branches where id = my_branch and status = 'active') then
    raise exception 'NOT_ALLOWED';
  end if;

  select first_name || ' ' || last_name into staff_name
  from public.staff_members where account_id = auth.uid();

  -- The same medicine can't be requested twice while still open
  if exists (
    select 1 from public.medicine_requests r
    where r.branch_id = my_branch and r.status = 'open'
      and lower(r.generic_name) = lower(trim(p->>'generic_name'))
      and lower(coalesce(r.strength, '')) = lower(coalesce(trim(p->>'strength'), ''))
  ) then
    raise exception 'DUPLICATE_REQUEST';
  end if;

  insert into public.medicine_requests
    (branch_id, requested_by, requested_by_label, generic_name, brand_name, strength,
     dosage_form, registration_number, notes)
  values
    (my_branch, auth.uid(), staff_name, trim(p->>'generic_name'),
     nullif(trim(p->>'brand_name'), ''), nullif(trim(p->>'strength'), ''),
     nullif(trim(p->>'dosage_form'), ''), nullif(trim(p->>'registration_number'), ''),
     nullif(trim(p->>'notes'), ''))
  returning display_id into new_display_id;

  -- Let every admin know
  insert into public.notifications (recipient_id, type, title, body)
  select a.account_id, 'medicine_request', 'New medicine request',
         trim(p->>'generic_name') || ' was requested by a pharmacy.'
  from public.admins a where a.is_active;

  perform public.log_activity(my_branch, auth.uid(), staff_name, public.my_staff_role()::text,
    'Requested a medicine', 'medicine_request', new_display_id);

  return new_display_id;
end
$$;

-- Admin list of requests, open ones first
create or replace function public.admin_list_medicine_requests(p_status public.request_status default null)
returns table (
  id uuid,
  display_id text,
  generic_name text,
  brand_name text,
  strength text,
  dosage_form text,
  registration_number text,
  notes text,
  status public.request_status,
  dismiss_reason text,
  pharmacy_name text,
  branch_name text,
  requested_by_label text,
  created_at timestamptz,
  resolved_medicine_id uuid
)
language sql stable security definer
set search_path = ''
as $$
  select r.id, r.display_id, r.generic_name, r.brand_name, r.strength, r.dosage_form,
         r.registration_number, r.notes, r.status, r.dismiss_reason,
         b.pharmacy_name, b.branch_name, r.requested_by_label, r.created_at, r.resolved_medicine_id
  from public.medicine_requests r
  join public.branches b on b.id = r.branch_id
  where public.is_admin()
    and (p_status is null or r.status = p_status)
  order by (r.status = 'open') desc, r.created_at desc
$$;

-- Mark a request as added, linking it to the catalogue medicine
create or replace function public.mark_request_added(p_request_id uuid, p_medicine_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  req public.medicine_requests%rowtype;
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into req from public.medicine_requests where id = p_request_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if req.status <> 'open' then
    raise exception 'NOT_OPEN';
  end if;
  if not exists (select 1 from public.medicines where id = p_medicine_id) then
    raise exception 'MEDICINE_NOT_FOUND';
  end if;

  update public.medicine_requests set
    status = 'added', resolved_medicine_id = p_medicine_id,
    resolved_by = auth.uid(), resolved_at = now()
  where id = req.id;

  -- Tell the person who asked
  insert into public.notifications (recipient_id, type, title, body)
  values (req.requested_by, 'medicine_request_added', 'Medicine request added',
          req.generic_name || ' is now in the catalogue. You can add it to your inventory once it is active.');

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    'Marked medicine request as added', req.display_id);
end
$$;

-- Dismiss a request, with a reason the pharmacy will see
create or replace function public.dismiss_medicine_request(p_request_id uuid, p_reason text)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  req public.medicine_requests%rowtype;
  reason text := trim(coalesce(p_reason, ''));
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;
  if length(reason) not between 5 and 200 then
    raise exception 'REASON_LENGTH';
  end if;

  select * into req from public.medicine_requests where id = p_request_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if req.status <> 'open' then
    raise exception 'NOT_OPEN';
  end if;

  update public.medicine_requests set
    status = 'dismissed', dismiss_reason = reason,
    resolved_by = auth.uid(), resolved_at = now()
  where id = req.id;

  -- Tell the person who asked, with the reason
  insert into public.notifications (recipient_id, type, title, body)
  values (req.requested_by, 'medicine_request_dismissed', 'Medicine request not added', reason);

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    'Dismissed medicine request', req.display_id, jsonb_build_object('reason', reason));
end
$$;

-- Signed-in users may call these; each checks the caller itself
revoke execute on function public.submit_medicine_request(jsonb) from public, anon;
revoke execute on function public.admin_list_medicine_requests(public.request_status) from public, anon;
revoke execute on function public.mark_request_added(uuid, uuid) from public, anon;
revoke execute on function public.dismiss_medicine_request(uuid, text) from public, anon;
grant execute on function public.submit_medicine_request(jsonb) to authenticated;
grant execute on function public.admin_list_medicine_requests(public.request_status) to authenticated;
grant execute on function public.mark_request_added(uuid, uuid) to authenticated;
grant execute on function public.dismiss_medicine_request(uuid, text) to authenticated;