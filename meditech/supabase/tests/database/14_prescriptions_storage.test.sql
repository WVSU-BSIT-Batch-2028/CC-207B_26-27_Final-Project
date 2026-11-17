begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

-- =====================================================================
-- 1. BUCKET & FUNCTION EXISTENCE
-- =====================================================================

select ok(
  exists (select 1 from storage.buckets where id = 'prescriptions' and not public),
  'prescriptions bucket exists and is private');

select has_function('public', 'get_prescription_url', 'get_prescription_url function exists');

-- =====================================================================
-- 2. TEST SETUP: USERS, BRANCHES, RESERVATION & PRESCRIPTION
-- =====================================================================

-- Branch 1 (La Paz)
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status, approved_at)
values
  ('bbbbbbbb-1111-0000-0000-000000000001', 'Test Pharma', 'Branch 1',
   '12 Rizal St, Iloilo', '0333201111', 'b1@test.com',
   10.7202, 122.5621, 'LTO-TEST-0001', '2028-12-31', 'active', now()),
  ('bbbbbbbb-2222-0000-0000-000000000002', 'Test Pharma', 'Branch 2',
   '45 Lopez St, Iloilo', '0333202222', 'b2@test.com',
   10.7275, 122.5577, 'LTO-TEST-0002', '2028-12-31', 'active', now());

-- Customer A (Owner of reservation)
insert into auth.users (id, email) values
  ('cccccccc-1111-0000-0000-000000000001', 'cust.a@test.com'),
  ('cccccccc-2222-0000-0000-000000000002', 'cust.b@test.com'),
  ('ssssssss-1111-0000-0000-000000000001', 'staff.b1@test.com'),
  ('ssssssss-2222-0000-0000-000000000002', 'staff.b2@test.com'),
  ('aaaaaaaa-1111-0000-0000-000000000001', 'admin.test@test.com');

insert into public.accounts (id, account_type) values
  ('cccccccc-1111-0000-0000-000000000001', 'customer'),
  ('cccccccc-2222-0000-0000-000000000002', 'customer'),
  ('ssssssss-1111-0000-0000-000000000001', 'staff'),
  ('ssssssss-2222-0000-0000-000000000002', 'staff'),
  ('aaaaaaaa-1111-0000-0000-000000000001', 'admin');

insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values
  ('cccccccc-1111-0000-0000-000000000001', 'Customer', 'One', '09110000001',
   'cust.a@test.com', '1995-01-01', 'v1'),
  ('cccccccc-2222-0000-0000-000000000002', 'Customer', 'Two', '09110000002',
   'cust.b@test.com', '1996-02-02', 'v1');

insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name,
   prc_license_no, prc_license_expiry, license_status)
values
  ('ssssssss-1111-0000-0000-000000000001', 'bbbbbbbb-1111-0000-0000-000000000001',
   'pharmacist', 'Jose', 'Reyes', '0123456', '2030-12-31', 'verified'),
  ('ssssssss-2222-0000-0000-000000000002', 'bbbbbbbb-2222-0000-0000-000000000002',
   'pharmacist', 'Maria', 'Santos', '0654321', '2030-12-31', 'verified');

insert into public.admins (account_id, display_name)
values ('aaaaaaaa-1111-0000-0000-000000000001', 'Test Admin');

-- Create a reservation at Branch 1
insert into public.reservations
  (id, reference_no, customer_id, branch_id, total_amount, expires_at, idempotency_key)
values
  ('rrrrrrrr-1111-0000-0000-000000000001', 'RM-111726-0001',
   'cccccccc-1111-0000-0000-000000000001', 'bbbbbbbb-1111-0000-0000-000000000001',
   50.00, now() + interval '7 days', 'eeeeeeee-1111-0000-0000-000000000001');

-- Attach a prescription to this reservation
insert into public.reservation_prescriptions
  (id, reservation_id, storage_path, mime_type, size_bytes)
values
  ('pppppppp-1111-0000-0000-000000000001', 'rrrrrrrr-1111-0000-0000-000000000001',
   'cccccccc-1111-0000-0000-000000000001/rx_sample.jpg', 'image/jpeg', 2048);

-- Add a mock storage object for testing RLS
insert into storage.objects
  (id, bucket_id, name, owner)
values
  ('99999999-1111-0000-0000-000000000001', 'prescriptions',
   'cccccccc-1111-0000-0000-000000000001/rx_sample.jpg', 'cccccccc-1111-0000-0000-000000000001');

-- =====================================================================
-- HELPER: auth simulation
-- =====================================================================
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
-- 3. PERMISSION & REFUSAL TESTS
-- =====================================================================

-- Admin cannot view prescriptions
select set_auth_user('aaaaaaaa-1111-0000-0000-000000000001');
select throws_ok(
  $$ select public.get_prescription_url('pppppppp-1111-0000-0000-000000000001') $$,
  null, 'Admins cannot view prescriptions',
  'admin is refused when requesting a prescription');
select reset_auth();

-- Staff at Branch 2 cannot view Branch 1 prescriptions
select set_auth_user('ssssssss-2222-0000-0000-000000000002');
select throws_ok(
  $$ select public.get_prescription_url('pppppppp-1111-0000-0000-000000000001') $$,
  null, 'This prescription belongs to a different branch',
  'staff at another branch cannot view prescriptions');
select reset_auth();

-- Another customer cannot view Customer A's prescription
select set_auth_user('cccccccc-2222-0000-0000-000000000002');
select throws_ok(
  $$ select public.get_prescription_url('pppppppp-1111-0000-0000-000000000001') $$,
  null, 'You can only view your own prescriptions',
  'other customer cannot view another customer prescription');
select reset_auth();

-- Non-existent prescription ID throws
select set_auth_user('ssssssss-1111-0000-0000-000000000001');
select throws_ok(
  $$ select public.get_prescription_url('00000000-0000-0000-0000-000000000000') $$,
  null, 'Prescription not found',
  'non-existent prescription raises error');
select reset_auth();

-- Mismatched reservation ID throws
select set_auth_user('ssssssss-1111-0000-0000-000000000001');
select throws_ok(
  $$ select public.get_prescription_url(
       'pppppppp-1111-0000-0000-000000000001',
       '00000000-0000-0000-0000-000000000000') $$,
  null, 'Prescription does not belong to this reservation',
  'mismatched reservation ID is rejected');
select reset_auth();

-- =====================================================================
-- 4. SUCCESS TESTS
-- =====================================================================

-- Customer A can view their own prescription
select set_auth_user('cccccccc-1111-0000-0000-000000000001');
select is(
  public.get_prescription_url('pppppppp-1111-0000-0000-000000000001'),
  'cccccccc-1111-0000-0000-000000000001/rx_sample.jpg',
  'customer can retrieve their own prescription path');
select reset_auth();

-- Staff at Branch 1 can view the prescription
select set_auth_user('ssssssss-1111-0000-0000-000000000001');
select is(
  public.get_prescription_url('pppppppp-1111-0000-0000-000000000001'),
  'cccccccc-1111-0000-0000-000000000001/rx_sample.jpg',
  'branch staff retrieves prescription path successfully');
select reset_auth();

-- Viewing by staff logged an activity record for the pharmacy owner
select ok(
  exists (
    select 1 from public.activity_log
    where branch_id = 'bbbbbbbb-1111-0000-0000-000000000001'
      and action = 'Viewed prescription'
      and entity_id = 'RM-111726-0001'
  ),
  'viewing prescription is logged in activity_log');

-- =====================================================================
-- 5. STORAGE OBJECTS RLS POLICIES
-- =====================================================================

-- Customer A can see their own object
select set_auth_user('cccccccc-1111-0000-0000-000000000001');
select is(
  (select count(*) from storage.objects where bucket_id = 'prescriptions'),
  1::bigint,
  'customer A can select their own prescription object');
select reset_auth();

-- Customer B cannot see Customer A's object
select set_auth_user('cccccccc-2222-0000-0000-000000000002');
select is(
  (select count(*) from storage.objects where bucket_id = 'prescriptions'),
  0::bigint,
  'customer B cannot see customer A prescription object');
select reset_auth();

-- Branch 1 staff can see the object (attached to their branch reservation)
select set_auth_user('ssssssss-1111-0000-0000-000000000001');
select is(
  (select count(*) from storage.objects where bucket_id = 'prescriptions'),
  1::bigint,
  'branch 1 staff can select prescription object attached to branch reservation');
select reset_auth();

-- Branch 2 staff cannot see the object
select set_auth_user('ssssssss-2222-0000-0000-000000000002');
select is(
  (select count(*) from storage.objects where bucket_id = 'prescriptions'),
  0::bigint,
  'branch 2 staff cannot see prescription object for other branch');
select reset_auth();

-- Admin cannot see the object
select set_auth_user('aaaaaaaa-1111-0000-0000-000000000001');
select is(
  (select count(*) from storage.objects where bucket_id = 'prescriptions'),
  0::bigint,
  'admin cannot see prescription object in storage');
select reset_auth();

-- Finish test
select * from finish();
rollback;
