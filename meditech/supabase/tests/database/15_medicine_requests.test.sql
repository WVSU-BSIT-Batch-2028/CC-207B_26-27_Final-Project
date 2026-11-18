begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- Two approved pharmacies, a staff member at each, an admin, and a customer
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Pharmacy X', 'Main', 'Iloilo City',
   '0333201234', 'x.q@test.com', 10.72, 122.56, 'LTO-Q-X', '2028-12-31', 'active'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Pharmacy Y', 'Main', 'Iloilo City',
   '0333201235', 'y.q@test.com', 10.73, 122.57, 'LTO-Q-Y', '2028-12-31', 'active');
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'staff.x.q@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'staff.y.q@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'admin.q@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'cust.q@test.com');
insert into public.accounts (id, account_type, username) values
  ('11111111-1111-1111-1111-111111111111', 'staff', 'staff_x_q'),
  ('22222222-2222-2222-2222-222222222222', 'staff', 'staff_y_q'),
  ('33333333-3333-3333-3333-333333333333', 'admin', 'admin_q'),
  ('44444444-4444-4444-4444-444444444444', 'customer', null);
insert into public.staff_members (account_id, branch_id, role, first_name, last_name) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'staff', 'Ana', 'Lim'),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'staff', 'Ben', 'Cruz');
insert into public.admins (account_id, display_name)
values ('33333333-3333-3333-3333-333333333333', 'Request Admin');

-- Staff at X sends a request
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
select lives_ok($$ select public.submit_medicine_request(jsonb_build_object(
  'generic_name', 'Cefalexin', 'brand_name', 'Keflex', 'strength', '500 mg',
  'dosage_form', 'Capsule', 'notes', 'Patients keep asking')) $$,
  'staff sends a medicine request');

-- The same request can't be sent twice while open
select throws_ok($$ select public.submit_medicine_request(jsonb_build_object(
  'generic_name', 'cefalexin', 'strength', '500 MG')) $$,
  'P0001', 'DUPLICATE_REQUEST', 'duplicate open request is refused');

-- Staff at X sees their request; staff at Y doesn't
select is((select count(*) from public.medicine_requests where generic_name = 'Cefalexin'),
  1::bigint, 'own branch sees its request');
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
select is((select count(*) from public.medicine_requests where generic_name = 'Cefalexin'),
  0::bigint, 'other branch cannot see it');

-- A customer can't send requests
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444"}', true);
select throws_ok($$ select public.submit_medicine_request(jsonb_build_object('generic_name', 'Ibuprofen')) $$,
  'P0001', 'NOT_ALLOWED', 'customers cannot request medicines');

-- The admin sees it and was notified
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', true);
select is((select count(*) from public.admin_list_medicine_requests('open') where generic_name = 'Cefalexin'),
  1::bigint, 'admin sees the open request');
reset role;
select ok((select count(*) from public.notifications
           where recipient_id = '33333333-3333-3333-3333-333333333333' and type = 'medicine_request') >= 1,
  'admin is notified of the request');

-- Dismissing needs a proper reason, and tells the requester
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', true);
select throws_ok($$ select public.dismiss_medicine_request(
  (select id from public.medicine_requests where generic_name = 'Cefalexin'), 'no') $$,
  'P0001', 'REASON_LENGTH', 'too-short reason is refused');
select lives_ok($$ select public.dismiss_medicine_request(
  (select id from public.medicine_requests where generic_name = 'Cefalexin'),
  'Cefalexin is already listed under the brand Keflex. Search for "Keflex".') $$,
  'admin dismisses with a reason');
reset role;
select is((select count(*) from public.notifications
           where recipient_id = '11111111-1111-1111-1111-111111111111'
             and type = 'medicine_request_dismissed'),
  1::bigint, 'requester is told why');

-- Undo all test data
select * from finish();
rollback;