-- Background jobs: expire old reservations, send reminders, mark expired
-- licenses, purge unused uploads, and let admins deactivate or reactivate a branch

create extension if not exists pg_cron with schema pg_catalog;

-- =====================================================================
-- Helper: close a reservation on behalf of the system or an admin.
-- Releases any held stock, saves the status change, and tells the customer.
-- =====================================================================
create or replace function public._close_reservation(
  p_reservation_id uuid,
  p_to_status public.reservation_status,
  p_reason text,
  p_actor_id uuid,
  p_actor_role text,
  p_title text,
  p_body text,
  p_notification_type text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res record;
  v_item record;
begin
  select * into v_res
  from public.reservations
  where id = p_reservation_id
  for update;

  -- Only open reservations can be closed
  if v_res is null or v_res.status not in ('pending', 'confirmed', 'ready_for_pickup') then
    return;
  end if;

  -- Give back any held stock
  for v_item in
    select ri.line_no, ri.inventory_item_id, ri.held_quantity
    from public.reservation_items ri
    where ri.reservation_id = p_reservation_id and ri.held_quantity > 0
    order by ri.line_no
  loop
    update public.inventory_items
    set held_quantity = greatest(held_quantity - v_item.held_quantity, 0)
    where id = v_item.inventory_item_id;

    update public.reservation_items
    set held_quantity = 0
    where reservation_id = p_reservation_id and line_no = v_item.line_no;
  end loop;

  update public.reservations
  set status = p_to_status,
      closed_reason = p_reason,
      closed_by = p_actor_id
  where id = p_reservation_id;

  insert into public.reservation_status_history
    (reservation_id, from_status, to_status, actor_id, actor_role, reason)
  values
    (p_reservation_id, v_res.status, p_to_status, p_actor_id, p_actor_role, p_reason);

  insert into public.notifications (recipient_id, type, title, body, reservation_id)
  values (v_res.customer_id, p_notification_type,
          'Reservation ' || v_res.reference_no || ' ' || p_title,
          p_body, p_reservation_id);
end
$$;

revoke execute on function public._close_reservation(
  uuid, public.reservation_status, text, uuid, text, text, text, text
) from public, anon, authenticated;

-- =====================================================================
-- 1. EXPIRE RESERVATIONS (every 10 minutes)
-- Reservations still open after their 7 days are expired and stock is freed.
-- Returns how many were expired.
-- =====================================================================
create or replace function public.expire_reservations()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res record;
  v_count int := 0;
begin
  for v_res in
    select id, branch_id, reference_no
    from public.reservations
    where status in ('pending', 'confirmed', 'ready_for_pickup')
      and expires_at <= now()
    order by expires_at
    for update skip locked
  loop
    perform public._close_reservation(
      v_res.id, 'expired', 'Reservation expired', null, 'system',
      'expired',
      'Your reservation was not picked up in time, so it has expired.',
      'reservation_expired'
    );

    perform public.log_activity(
      v_res.branch_id, null, 'System', 'system',
      'Reservation expired', 'reservation', v_res.reference_no
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end
$$;

revoke execute on function public.expire_reservations() from public, anon, authenticated;

-- =====================================================================
-- 2. REMIND CUSTOMERS (every hour)
-- One reminder for confirmed or ready reservations that expire within a day.
-- Returns how many reminders were sent.
-- =====================================================================
create or replace function public.send_expiry_reminders()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res record;
  v_count int := 0;
begin
  for v_res in
    select id, customer_id, reference_no, expires_at
    from public.reservations
    where status in ('confirmed', 'ready_for_pickup')
      and reminder_sent_at is null
      and expires_at > now()
      and expires_at <= now() + interval '1 day'
    for update skip locked
  loop
    insert into public.notifications
      (recipient_id, type, title, body, reservation_id, dedupe_key)
    values
      (v_res.customer_id, 'reservation_reminder',
       'Reservation ' || v_res.reference_no || ' expires soon',
       'Please pick up your reservation within a day or it will expire.',
       v_res.id, 'reminder:' || v_res.id)
    on conflict (dedupe_key) do nothing;

    update public.reservations
    set reminder_sent_at = now()
    where id = v_res.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end
$$;

revoke execute on function public.send_expiry_reminders() from public, anon, authenticated;

-- =====================================================================
-- 3. EXPIRED LICENSE CHECK (every night)
-- Verified licenses past their expiry date become "expired".
-- The staff member and the branch owner are told. Returns the count.
-- =====================================================================
create or replace function public.expire_licenses()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff record;
  v_count int := 0;
begin
  for v_staff in
    select sm.account_id, sm.branch_id, sm.first_name, sm.last_name,
           sm.prc_license_expiry, sm.display_id
    from public.staff_members sm
    where sm.license_status = 'verified'
      and sm.prc_license_expiry < public.app_today()
    for update skip locked
  loop
    update public.staff_members
    set license_status = 'expired'
    where account_id = v_staff.account_id;

    -- Tell the staff member
    insert into public.notifications (recipient_id, type, title, body, dedupe_key)
    values (v_staff.account_id, 'license_expired',
            'Your PRC license has expired',
            'Your license expired on ' || v_staff.prc_license_expiry
              || '. Ask your owner to update it before you can confirm reservations again.',
            'license-expired:' || v_staff.account_id || ':' || v_staff.prc_license_expiry)
    on conflict (dedupe_key) do nothing;

    -- Tell the owner (unless the owner is the one who expired)
    insert into public.notifications (recipient_id, type, title, body, dedupe_key)
    select o.account_id, 'license_expired',
           'A team license has expired',
           v_staff.first_name || ' ' || v_staff.last_name || ' (' || v_staff.display_id
             || ') has an expired PRC license.',
           'license-expired-owner:' || v_staff.account_id || ':' || v_staff.prc_license_expiry
    from public.staff_members o
    where o.branch_id = v_staff.branch_id
      and o.role = 'owner'
      and o.is_active
      and o.account_id <> v_staff.account_id
    on conflict (dedupe_key) do nothing;

    perform public.log_activity(
      v_staff.branch_id, null, 'System', 'system',
      'License marked expired', 'staff', v_staff.display_id,
      jsonb_build_object('expired_on', v_staff.prc_license_expiry)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end
$$;

revoke execute on function public.expire_licenses() from public, anon, authenticated;

-- =====================================================================
-- 4. PURGE UNUSED UPLOADS (every night)
-- Prescription photos left in a cart for over a day are forgotten.
-- Returns how many were removed.
-- =====================================================================
create or replace function public.purge_unused_uploads()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  delete from public.cart_prescription_files
  where uploaded_at < now() - interval '1 day';

  get diagnostics v_count = row_count;
  return v_count;
end
$$;

revoke execute on function public.purge_unused_uploads() from public, anon, authenticated;

-- =====================================================================
-- 5. DEACTIVATE BRANCH
-- An admin takes an active branch offline with a reason. Open reservations
-- are closed (pending ones rejected, confirmed ones cancelled) and stock
-- holds are released. Customers are told.
-- =====================================================================
create or replace function public.deactivate_branch(
  p_branch_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_branch record;
  v_res record;
  v_label text;
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if not public.is_admin() then
    raise exception 'Only administrators can deactivate a branch';
  end if;

  if length(v_reason) < 5 or length(v_reason) > 200 then
    raise exception 'Reason must be between 5 and 200 characters';
  end if;

  select * into v_branch
  from public.branches
  where id = p_branch_id
  for update;

  if v_branch is null then
    raise exception 'Branch not found';
  end if;

  if v_branch.status <> 'active' then
    raise exception 'Only active branches can be deactivated';
  end if;

  -- Close every open reservation at this branch
  for v_res in
    select id, status
    from public.reservations
    where branch_id = p_branch_id
      and status in ('pending', 'confirmed', 'ready_for_pickup')
    order by submitted_at
  loop
    perform public._close_reservation(
      v_res.id,
      case when v_res.status = 'pending' then 'rejected'::public.reservation_status
           else 'cancelled'::public.reservation_status end,
      v_reason, v_admin_id, 'admin',
      case when v_res.status = 'pending' then 'rejected' else 'cancelled' end,
      'This pharmacy is no longer taking reservations. Reason: ' || v_reason,
      case when v_res.status = 'pending' then 'reservation_rejected'
           else 'reservation_cancelled' end
    );
  end loop;

  -- Empty carts for this branch so nobody can order from it
  delete from public.carts where branch_id = p_branch_id;

  update public.branches
  set status = 'inactive', deactivation_reason = v_reason
  where id = p_branch_id;

  select display_name into v_label from public.admins where account_id = v_admin_id;

  perform public.log_audit(
    v_admin_id, coalesce(v_label, 'Admin'), 'admin', 'admin_action',
    'Deactivated a pharmacy branch', v_branch.display_id,
    jsonb_build_object('reason', v_reason)
  );
  perform public.log_activity(
    p_branch_id, v_admin_id, coalesce(v_label, 'Admin'), 'admin',
    'Branch deactivated', 'branch', v_branch.display_id,
    jsonb_build_object('reason', v_reason)
  );
end
$$;

-- =====================================================================
-- 6. ACTIVATE BRANCH
-- An admin brings an inactive branch back online.
-- =====================================================================
create or replace function public.activate_branch(p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_branch record;
  v_label text;
begin
  if not public.is_admin() then
    raise exception 'Only administrators can activate a branch';
  end if;

  select * into v_branch
  from public.branches
  where id = p_branch_id
  for update;

  if v_branch is null then
    raise exception 'Branch not found';
  end if;

  if v_branch.status <> 'inactive' then
    raise exception 'Only inactive branches can be activated';
  end if;

  update public.branches
  set status = 'active', deactivation_reason = null
  where id = p_branch_id;

  select display_name into v_label from public.admins where account_id = v_admin_id;

  perform public.log_audit(
    v_admin_id, coalesce(v_label, 'Admin'), 'admin', 'admin_action',
    'Reactivated a pharmacy branch', v_branch.display_id
  );
  perform public.log_activity(
    p_branch_id, v_admin_id, coalesce(v_label, 'Admin'), 'admin',
    'Branch reactivated', 'branch', v_branch.display_id
  );
end
$$;

-- Admins call these from the app; everyone else is refused inside the function
revoke execute on function public.deactivate_branch(uuid, text) from public, anon;
revoke execute on function public.activate_branch(uuid) from public, anon;
grant execute on function public.deactivate_branch(uuid, text) to authenticated;
grant execute on function public.activate_branch(uuid) to authenticated;

-- =====================================================================
-- SCHEDULE (times are UTC; 16:00 UTC is midnight in the Philippines)
-- =====================================================================
do $$
begin
  if exists (select 1 from cron.job where jobname = 'expire-reservations') then
    perform cron.unschedule('expire-reservations');
  end if;
  perform cron.schedule('expire-reservations', '*/10 * * * *',
    'select public.expire_reservations()');

  if exists (select 1 from cron.job where jobname = 'reservation-reminders') then
    perform cron.unschedule('reservation-reminders');
  end if;
  perform cron.schedule('reservation-reminders', '0 * * * *',
    'select public.send_expiry_reminders()');

  if exists (select 1 from cron.job where jobname = 'expire-licenses') then
    perform cron.unschedule('expire-licenses');
  end if;
  perform cron.schedule('expire-licenses', '0 16 * * *',
    'select public.expire_licenses()');

  if exists (select 1 from cron.job where jobname = 'purge-unused-uploads') then
    perform cron.unschedule('purge-unused-uploads');
  end if;
  perform cron.schedule('purge-unused-uploads', '30 16 * * *',
    'select public.purge_unused_uploads()');
end
$$;
