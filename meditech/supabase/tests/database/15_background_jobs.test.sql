begin;
create extension if not exists pgtap with schema extensions;
select plan(44);

-- =====================================================================
-- TEST DATA SETUP
-- =====================================================================

-- Two customers
insert into auth.users (id, email) values
  ('b1000000-0000-0000-0000-000000000001', 'jobs.customer1@test.com'),
  ('b1000000-0000-0000-0000-000000000002', 'jobs.customer2@test.com');
insert into public.accounts (id, account_type) values
  ('b1000000-0000-0000-0000-000000000001', 'customer'),
  ('b1000000-0000-0000-0000-000000000002', 'customer');
insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values
  ('b1000000-0000-0000-0000-000000000001', 'Jobs', 'One', '09991000001',
   'jobs.customer1@test.com', '1995-01-01', 'v1'),
  ('b1000000-0000-0000-0000-000000000002', 'Jobs', 'Two', '09991000002',
   'jobs.customer2@test.com', '1996-02-02', 'v1');

-- One active branch
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status, approved_at)
values
  ('b2000000-0000-0000-0000-000000000001', 'Jobs Pharmacy', 'Jobs Branch',
   '1 Job St, Test City', '0330000101', 'jobs@pharmacy.com',
   10.7202, 122.5621, 'JOBS-LTO-0001', '2028-12-31', 'active', now());

-- Owner, a pharmacist whose license ran out, and a pharmacist with a valid license
insert into auth.users (id, email) values
  ('b3000000-0000-0000-0000-000000000001', 'jobs.owner@test.com'),
  ('b3000000-0000-0000-0000-000000000002', 'jobs.old@test.com'),
  ('b3000000-0000-0000-0000-000000000003', 'jobs.new@test.com');
insert into public.accounts (id, account_type) values
  ('b3000000-0000-0000-0000-000000000001', 'staff'),
  ('b3000000-0000-0000-0000-000000000002', 'staff'),
  ('b3000000-0000-0000-0000-000000000003', 'staff');
insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name,
   prc_license_no, prc_license_expiry, license_status)
values
  ('b3000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001',
   'owner', 'Jobs', 'Owner', null, null, 'none'),
  ('b3000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001',
   'pharmacist', 'Old', 'License', '8888881', '2020-01-01', 'verified'),
  ('b3000000-0000-0000-0000-000000000003', 'b2000000-0000-0000-0000-000000000001',
   'pharmacist', 'New', 'License', '8888882', '2035-01-01', 'verified');

-- Admin
insert into auth.users (id, email) values
  ('b4000000-0000-0000-0000-000000000001', 'jobs.admin@test.com');
insert into public.accounts (id, account_type) values
  ('b4000000-0000-0000-0000-000000000001', 'admin');
insert into public.admins (account_id, display_name)
values ('b4000000-0000-0000-0000-000000000001', 'Jobs Admin');

-- A medicine with 100 in stock, 15 of it held (10 for reservation A, 5 for C)
insert into public.medicines
  (id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status)
values
  ('b5000000-0000-0000-0000-000000000001', 'JobsMed', 'JobsGeneric', '500 mg',
   (select id from public.dosage_forms where name = 'Tablet'),
   (select id from public.units where name = 'tablet'), false, 'active');
insert into public.inventory_items
  (id, branch_id, medicine_id, stock_quantity, held_quantity, price_per_unit)
values
  ('b6000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001',
   'b5000000-0000-0000-0000-000000000001', 100, 15, 5.00);

-- Reservations
--   A: confirmed, ran out 1 day ago, holds 10
--   B: pending, ran out 1 day ago
--   C: confirmed, runs out in 12 hours, holds 5
--   D: confirmed, runs out in 3 days
--   E: pending, just placed
insert into public.reservations
  (id, reference_no, customer_id, branch_id, status, total_amount,
   submitted_at, expires_at, idempotency_key)
values
  ('b7000000-0000-0000-0000-00000000000a', 'RM-111326-0001',
   'b1000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001',
   'confirmed', 50, now() - interval '8 days', now() - interval '1 day',
   'b8000000-0000-0000-0000-00000000000a'),
  ('b7000000-0000-0000-0000-00000000000b', 'RM-111326-0002',
   'b1000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001',
   'pending', 25, now() - interval '8 days', now() - interval '1 day',
   'b8000000-0000-0000-0000-00000000000b'),
  ('b7000000-0000-0000-0000-00000000000c', 'RM-111326-0003',
   'b1000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001',
   'confirmed', 25, now() - interval '6 days 12 hours', now() + interval '12 hours',
   'b8000000-0000-0000-0000-00000000000c'),
  ('b7000000-0000-0000-0000-00000000000d', 'RM-111326-0004',
   'b1000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001',
   'confirmed', 25, now() - interval '4 days', now() + interval '3 days',
   'b8000000-0000-0000-0000-00000000000d'),
  ('b7000000-0000-0000-0000-00000000000e', 'RM-111326-0005',
   'b1000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001',
   'pending', 25, now(), now() + interval '7 days',
   'b8000000-0000-0000-0000-00000000000e');

insert into public.reservation_items
  (reservation_id, line_no, medicine_id, inventory_item_id, quantity, held_quantity,
   brand_name, generic_name, strength, dosage_form, unit_sold, is_rx, unit_price)
select r.id, 1, 'b5000000-0000-0000-0000-000000000001',
       'b6000000-0000-0000-0000-000000000001', q.qty, q.held,
       'JobsMed', 'JobsGeneric', '500 mg', 'Tablet', 'tablet', false, 5.00
from (values
  ('b7000000-0000-0000-0000-00000000000a'::uuid, 10, 10),
  ('b7000000-0000-0000-0000-00000000000b'::uuid, 5, 0),
  ('b7000000-0000-0000-0000-00000000000c'::uuid, 5, 5),
  ('b7000000-0000-0000-0000-00000000000d'::uuid, 5, 0),
  ('b7000000-0000-0000-0000-00000000000e'::uuid, 5, 0)
) as q(rid, qty, held)
join public.reservations r on r.id = q.rid;

-- Switch the signed-in user
create or replace function set_auth_user(p_user_id uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end
$$;

create or replace function reset_auth()
returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end
$$;

-- =====================================================================
-- 1. THE JOBS EXIST
-- =====================================================================
select has_function('public', 'expire_reservations', 'expire_reservations exists');
select has_function('public', 'send_expiry_reminders', 'send_expiry_reminders exists');
select has_function('public', 'expire_licenses', 'expire_licenses exists');
select has_function('public', 'purge_unused_uploads', 'purge_unused_uploads exists');
select has_function('public', 'deactivate_branch', 'deactivate_branch exists');
select has_function('public', 'activate_branch', 'activate_branch exists');

select is(
  (select count(*)::int from cron.job
   where jobname in ('expire-reservations', 'reservation-reminders',
                     'expire-licenses', 'purge-unused-uploads')),
  4, 'all four background jobs are scheduled');

-- =====================================================================
-- 2. EXPIRE RESERVATIONS
-- =====================================================================
select is(public.expire_reservations(), 2, 'two overdue reservations are expired');

select is(
  (select status from public.reservations where id = 'b7000000-0000-0000-0000-00000000000a'),
  'expired'::public.reservation_status, 'overdue confirmed reservation is expired');

select is(
  (select held_quantity from public.inventory_items
   where id = 'b6000000-0000-0000-0000-000000000001'),
  5, 'expired reservation gives its held stock back');

select is(
  (select status from public.reservations where id = 'b7000000-0000-0000-0000-00000000000b'),
  'expired'::public.reservation_status, 'overdue pending reservation is expired');

select is(
  (select status from public.reservations where id = 'b7000000-0000-0000-0000-00000000000c'),
  'confirmed'::public.reservation_status, 'reservation that is not overdue is left alone');

select is(
  (select count(*)::int from public.reservation_status_history
   where reservation_id = 'b7000000-0000-0000-0000-00000000000a'
     and to_status = 'expired' and actor_role = 'system'),
  1, 'expiry is recorded in the status history');

select is(
  (select count(*)::int from public.notifications
   where recipient_id = 'b1000000-0000-0000-0000-000000000001'
     and type = 'reservation_expired'),
  2, 'customer is told about both expired reservations');

select is(public.expire_reservations(), 0, 'running it again expires nothing more');

-- =====================================================================
-- 3. REMINDERS
-- =====================================================================
select is(public.send_expiry_reminders(), 1, 'one reservation gets a reminder');

select isnt(
  (select reminder_sent_at from public.reservations
   where id = 'b7000000-0000-0000-0000-00000000000c'),
  null, 'reminder time is saved');

select is(
  (select reminder_sent_at from public.reservations
   where id = 'b7000000-0000-0000-0000-00000000000d'),
  null, 'reservation with days left gets no reminder');

select is(
  (select count(*)::int from public.notifications
   where recipient_id = 'b1000000-0000-0000-0000-000000000002'
     and type = 'reservation_reminder'),
  1, 'customer receives the reminder');

select is(public.send_expiry_reminders(), 0, 'no second reminder is sent');

-- =====================================================================
-- 4. EXPIRED LICENSES
-- =====================================================================
select is(public.expire_licenses(), 1, 'one expired license is found');

select is(
  (select license_status from public.staff_members
   where account_id = 'b3000000-0000-0000-0000-000000000002'),
  'expired'::public.license_status, 'license past its date becomes expired');

select is(
  (select license_status from public.staff_members
   where account_id = 'b3000000-0000-0000-0000-000000000003'),
  'verified'::public.license_status, 'valid license stays verified');

select is(
  (select count(*)::int from public.notifications
   where recipient_id = 'b3000000-0000-0000-0000-000000000001'
     and type = 'license_expired'),
  1, 'owner is told about the expired license');

select is(public.expire_licenses(), 0, 'running it again finds nothing new');

-- =====================================================================
-- 5. PURGE UNUSED UPLOADS
-- =====================================================================
insert into public.cart_prescription_files
  (customer_id, storage_path, mime_type, size_bytes, uploaded_at)
values
  ('b1000000-0000-0000-0000-000000000001', 'b1/old.jpg', 'image/jpeg', 1000,
   now() - interval '2 days'),
  ('b1000000-0000-0000-0000-000000000002', 'b2/new.jpg', 'image/jpeg', 1000, now());

select is(public.purge_unused_uploads(), 1, 'one stale upload is removed');

select is(
  (select count(*)::int from public.cart_prescription_files
   where storage_path = 'b2/new.jpg'),
  1, 'recent upload is kept');

-- =====================================================================
-- 6. DEACTIVATE AND ACTIVATE A BRANCH
-- =====================================================================
insert into public.carts (customer_id, branch_id)
values ('b1000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000001');

select set_auth_user('b1000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.deactivate_branch('b2000000-0000-0000-0000-000000000001', 'Closing for review') $$,
  null, 'Only administrators can deactivate a branch',
  'customer cannot deactivate a branch');
select reset_auth();

select set_auth_user('b3000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.deactivate_branch('b2000000-0000-0000-0000-000000000001', 'Closing for review') $$,
  null, 'Only administrators can deactivate a branch',
  'owner cannot deactivate their own branch');
select reset_auth();

select set_auth_user('b4000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.deactivate_branch('b2000000-0000-0000-0000-000000000001', 'no') $$,
  null, 'Reason must be between 5 and 200 characters',
  'a too-short reason is refused');

select lives_ok(
  $$ select public.deactivate_branch('b2000000-0000-0000-0000-000000000001', 'LTO under review') $$,
  'admin deactivates the branch');
select reset_auth();

select is(
  (select status from public.branches where id = 'b2000000-0000-0000-0000-000000000001'),
  'inactive'::public.branch_status, 'branch is now inactive');

select is(
  (select deactivation_reason from public.branches
   where id = 'b2000000-0000-0000-0000-000000000001'),
  'LTO under review', 'reason is saved');

select is(
  (select status from public.reservations where id = 'b7000000-0000-0000-0000-00000000000c'),
  'cancelled'::public.reservation_status, 'confirmed reservation is cancelled');

select is(
  (select status from public.reservations where id = 'b7000000-0000-0000-0000-00000000000e'),
  'rejected'::public.reservation_status, 'pending reservation is rejected');

select is(
  (select held_quantity from public.inventory_items
   where id = 'b6000000-0000-0000-0000-000000000001'),
  0, 'all held stock is given back');

select is(
  (select count(*)::int from public.carts
   where branch_id = 'b2000000-0000-0000-0000-000000000001'),
  0, 'carts for the branch are cleared');

select is(
  (select count(*)::int from public.audit_records
   where record_ref = (select display_id from public.branches
                       where id = 'b2000000-0000-0000-0000-000000000001')
     and action = 'Deactivated a pharmacy branch'),
  1, 'deactivation is written to the audit records');

select set_auth_user('b4000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.deactivate_branch('b2000000-0000-0000-0000-000000000001', 'Trying again') $$,
  null, 'Only active branches can be deactivated',
  'an inactive branch cannot be deactivated again');
select reset_auth();

select set_auth_user('b1000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.activate_branch('b2000000-0000-0000-0000-000000000001') $$,
  null, 'Only administrators can activate a branch',
  'customer cannot activate a branch');
select reset_auth();

select set_auth_user('b4000000-0000-0000-0000-000000000001');
select lives_ok(
  $$ select public.activate_branch('b2000000-0000-0000-0000-000000000001') $$,
  'admin activates the branch');
select reset_auth();

select is(
  (select status from public.branches where id = 'b2000000-0000-0000-0000-000000000001'),
  'active'::public.branch_status, 'branch is active again');

select is(
  (select deactivation_reason from public.branches
   where id = 'b2000000-0000-0000-0000-000000000001'),
  null, 'old deactivation reason is cleared');

select set_auth_user('b4000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.activate_branch('b2000000-0000-0000-0000-000000000001') $$,
  null, 'Only inactive branches can be activated',
  'an active branch cannot be activated again');
select reset_auth();

select * from finish();
rollback;
