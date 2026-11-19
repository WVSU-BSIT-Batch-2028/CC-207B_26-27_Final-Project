begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

-- A rejected owner and a customer
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner.r@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'cust.r@test.com');
insert into public.accounts (id, account_type, username, state) values
  ('11111111-1111-1111-1111-111111111111', 'staff', 'owner_r', 'rejected'),
  ('22222222-2222-2222-2222-222222222222', 'customer', null, 'active');
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status, rejection_reason)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Farmacia Tres', 'Main', 'Old address, Iloilo City',
   '0333201234', 'tres@test.com', 10.70, 122.54, 'LTO-R-1', '2028-12-31',
   'rejected', 'The address does not match the LTO.');
insert into public.branch_hours (branch_id, weekday, opens_at, closes_at)
select 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', d, '08:00', '20:00' from generate_series(0, 6) d;
insert into public.staff_members (account_id, branch_id, role, first_name, last_name, mobile)
values ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'owner', 'Ana', 'Reyes', '09171234567');

-- Act as the rejected owner
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);

-- The owner can load their application for editing
select is(public.my_application_for_edit() ->> 'address', 'Old address, Iloilo City',
  'owner loads their application for editing');

-- A file path in another pharmacy's folder is refused
select throws_ok($$ select public.resubmit_pharmacy_application(jsonb_build_object(
  'pharmacy_name', 'Farmacia Tres', 'branch_name', 'Main', 'address', 'New address, Iloilo City',
  'contact_number', '0333201234', 'pharmacy_email', 'tres@test.com',
  'latitude', 10.70, 'longitude', 122.54, 'lto_number', 'LTO-R-1', 'lto_expiry', '2028-12-31',
  'first_name', 'Ana', 'last_name', 'Reyes', 'mobile', '09179999999',
  'hours', (select jsonb_agg(jsonb_build_object('weekday', d, 'opens_at', '09:00', 'closes_at', '18:00'))
            from generate_series(0, 6) d),
  'documents', jsonb_build_array(jsonb_build_object('kind', 'lto', 'path', 'someone-else/lto/x.pdf',
               'mime_type', 'application/pdf', 'size_bytes', 100)))) $$,
  'P0001', 'BAD_DOCUMENT_PATH', 'files from another folder are refused');

-- A proper resubmission works
select lives_ok($$ select public.resubmit_pharmacy_application(jsonb_build_object(
  'pharmacy_name', 'Farmacia Tres', 'branch_name', 'Main', 'address', 'New address, Iloilo City',
  'contact_number', '0333201234', 'pharmacy_email', 'tres@test.com',
  'latitude', 10.70, 'longitude', 122.54, 'lto_number', 'LTO-R-1', 'lto_expiry', '2028-12-31',
  'first_name', 'Ana', 'last_name', 'Reyes', 'mobile', '09179999999',
  'hours', (select jsonb_agg(jsonb_build_object('weekday', d, 'opens_at', '09:00', 'closes_at', '18:00'))
            from generate_series(0, 6) d))) $$,
  'owner resubmits the fixed application');

-- Back in the review queue with the new details
reset role;
select is((select status from public.branches where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'pending_approval'::public.branch_status, 'application is pending again');
select is((select address from public.branches where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'New address, Iloilo City', 'address was updated');
select is((select state from public.accounts where id = '11111111-1111-1111-1111-111111111111'),
  'pending_approval'::public.account_state, 'owner waits for review again');

-- It can't be resubmitted again while pending
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
select throws_ok($$ select public.resubmit_pharmacy_application('{}'::jsonb) $$,
  'P0001', 'NOT_REJECTED', 'cannot resubmit while pending');

-- A customer can't resubmit anything
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
select throws_ok($$ select public.resubmit_pharmacy_application('{}'::jsonb) $$,
  'P0001', 'NOT_ALLOWED', 'customers cannot resubmit');

-- Undo all test data
reset role;
select * from finish();
rollback;