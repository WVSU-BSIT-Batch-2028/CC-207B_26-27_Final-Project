-- Customers may cancel their own pending reservations before pharmacy confirmation.
create or replace function public.customer_cancel_reservation(
  p_reservation_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := auth.uid();
  v_res record;
  v_customer_label text;
begin
  if v_customer_id is null or public.my_account_type() <> 'customer' then
    raise exception 'Only customers can cancel their own reservations';
  end if;

  select * into v_res
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_res is null then
    raise exception 'Reservation not found';
  end if;

  if v_res.customer_id <> v_customer_id then
    raise exception 'This reservation does not belong to you';
  end if;

  if v_res.status <> 'pending' then
    raise exception 'Only pending reservations can be cancelled';
  end if;

  update public.reservations
  set status = 'cancelled',
      closed_reason = 'Cancelled by customer',
      closed_by = v_customer_id
  where id = p_reservation_id;

  insert into public.reservation_status_history
    (reservation_id, from_status, to_status, actor_id, actor_role, reason)
  values
    (p_reservation_id, 'pending', 'cancelled', v_customer_id,
     'customer', 'Cancelled by customer');

  v_customer_label := public._customer_label(v_customer_id);

  insert into public.notifications (recipient_id, type, title, body, reservation_id)
  select sm.account_id, 'reservation_cancelled',
         'Reservation ' || v_res.reference_no || ' cancelled',
         coalesce(v_customer_label, 'A customer') ||
           ' cancelled reservation ' || v_res.reference_no || '.',
         p_reservation_id
  from public.staff_members sm
  where sm.branch_id = v_res.branch_id and sm.is_active;

  perform public.log_activity(
    v_res.branch_id, v_customer_id,
    coalesce(v_customer_label, 'Customer'),
    'customer', 'Cancelled reservation',
    'reservation', v_res.reference_no
  );
end
$$;

revoke all on function public.customer_cancel_reservation(uuid) from public, anon;
grant execute on function public.customer_cancel_reservation(uuid) to authenticated;