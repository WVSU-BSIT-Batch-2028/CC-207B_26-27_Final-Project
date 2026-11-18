-- Private storage bucket for prescription files, access rules,
-- and the prescription viewing link for pharmacy staff

-- =====================================================================
-- 1. PRESCRIPTIONS STORAGE BUCKET
-- Private bucket for prescription photos and PDFs (up to 5 MB each).
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('prescriptions', 'prescriptions', false, 5242880,
        array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

-- =====================================================================
-- 2. STORAGE POLICIES
-- Customers manage files inside their own folder (<customer_id>/...).
-- Staff can only view files attached to reservations at their branch.
-- Admins can never access prescriptions.
-- =====================================================================

-- Customers can upload prescription files to their own folder
create policy "Customers upload own prescriptions" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'prescriptions'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_account_type() = 'customer'
  );

-- Customers can view their own uploaded prescription files
create policy "Customers read own prescriptions" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'prescriptions'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_account_type() = 'customer'
  );

-- Customers can delete their own files before placing the reservation
create policy "Customers delete own prescriptions" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'prescriptions'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_account_type() = 'customer'
  );

-- Branch staff can read files attached to reservations for their branch
create policy "Staff read branch reservation prescriptions" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'prescriptions'
    and public.my_account_type() = 'staff'
    and exists (
      select 1
      from public.reservation_prescriptions rp
      join public.reservations r on r.id = rp.reservation_id
      where rp.storage_path = name
        and r.branch_id = public.my_branch_id()
    )
  );

-- =====================================================================
-- 3. GET PRESCRIPTION URL
-- Provides access to a prescription file for branch staff,
-- and logs every view in the pharmacy activity log.
-- =====================================================================
create or replace function public.get_prescription_url(
  p_prescription_id uuid,
  p_reservation_id uuid default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_account_type public.account_type := public.my_account_type();
  v_branch_id uuid := public.my_branch_id();
  v_res record;
  v_rp record;
  v_label text;
begin
  -- Administrators can never see prescriptions
  if public.is_admin() then
    raise exception 'Admins cannot view prescriptions';
  end if;

  -- Look up the prescription record
  select * into v_rp
  from public.reservation_prescriptions
  where id = p_prescription_id;

  if v_rp is null then
    raise exception 'Prescription not found';
  end if;

  -- If a reservation ID was provided, verify it matches
  if p_reservation_id is not null and v_rp.reservation_id <> p_reservation_id then
    raise exception 'Prescription does not belong to this reservation';
  end if;

  -- Look up the parent reservation
  select * into v_res
  from public.reservations
  where id = v_rp.reservation_id;

  if v_res is null then
    raise exception 'Reservation not found';
  end if;

  -- Pharmacy staff: must belong to the staff member's branch
  if v_account_type = 'staff' then
    if v_res.branch_id <> v_branch_id then
      raise exception 'This prescription belongs to a different branch';
    end if;

    -- Record that staff opened the prescription
    v_label := public._staff_label(v_actor_id);
    perform public.log_activity(
      v_res.branch_id, v_actor_id,
      coalesce(v_label, 'Staff'), public.my_staff_role()::text,
      'Viewed prescription', 'reservation', v_res.reference_no,
      jsonb_build_object(
        'prescription_id', v_rp.id,
        'display_id', v_rp.display_id,
        'storage_path', v_rp.storage_path
      )
    );

  -- Customer: must be the owner of the reservation
  elsif v_account_type = 'customer' then
    if v_res.customer_id <> v_actor_id then
      raise exception 'You can only view your own prescriptions';
    end if;

  else
    raise exception 'Access denied';
  end if;

  -- Return the storage path for viewing
  return v_rp.storage_path;
end;
$$;

-- Allow authenticated users (customers and staff) to request prescription viewing
grant execute on function public.get_prescription_url(uuid, uuid) to authenticated;
