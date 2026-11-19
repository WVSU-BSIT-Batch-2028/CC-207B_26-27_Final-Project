begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- An admin and a customer
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'admin.c@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'cust.c@test.com');
insert into public.accounts (id, account_type, username) values
  ('11111111-1111-1111-1111-111111111111', 'admin', 'admin_c'),
  ('22222222-2222-2222-2222-222222222222', 'customer', null);
insert into public.admins (account_id, display_name)
values ('11111111-1111-1111-1111-111111111111', 'Catalogue Admin');

-- Act as the admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);

-- Add a registration and a catalogue entry
select lives_ok($$ select public.admin_save_registration(jsonb_build_object(
  'registration_number', 'DR-TEST-0001', 'generic_name', 'Cefalexin', 'brand_name', 'Keflex',
  'strength', '500 mg', 'dosage_form_id', (select id from public.dosage_forms where name = 'Capsule'),
  'is_rx', true)) $$, 'admin adds a registration');

select lives_ok($$ select public.admin_save_medicine(jsonb_build_object(
  'registration_id', (select id from public.drug_registrations where registration_number = 'DR-TEST-0001'),
  'unit_sold_id', (select id from public.units where name = 'capsule'))) $$,
  'admin adds a catalogue entry');

-- New entries start as draft and copy the registration's details
select is((select m.status from public.medicines m
           join public.drug_registrations r on r.id = m.registration_id
           where r.registration_number = 'DR-TEST-0001'),
  'draft'::public.medicine_status, 'new entry starts as draft');
select ok((select m.is_rx from public.medicines m
           join public.drug_registrations r on r.id = m.registration_id
           where r.registration_number = 'DR-TEST-0001'),
  'entry copies the Rx flag from its registration');

-- The same registration in the same unit can't be added twice
select throws_ok($$ select public.admin_save_medicine(jsonb_build_object(
  'registration_id', (select id from public.drug_registrations where registration_number = 'DR-TEST-0001'),
  'unit_sold_id', (select id from public.units where name = 'capsule'))) $$,
  '23505', null, 'duplicate presentation is refused');

-- It can't go live without a matched FDA check
select throws_ok($$ select public.set_medicine_status(
  (select m.id from public.medicines m join public.drug_registrations r on r.id = m.registration_id
   where r.registration_number = 'DR-TEST-0001'), 'active') $$,
  'P0001', 'NEEDS_FDA_CHECK', 'cannot activate without an FDA check');

-- After a matched check, it can go live
select lives_ok($$ select public.record_registration_verification(
  (select id from public.drug_registrations where registration_number = 'DR-TEST-0001'), 'matched') $$,
  'admin records a matched product check');
select lives_ok($$ select public.set_medicine_status(
  (select m.id from public.medicines m join public.drug_registrations r on r.id = m.registration_id
   where r.registration_number = 'DR-TEST-0001'), 'active') $$,
  'entry goes live after a matched check');

-- Deactivating needs a proper reason
select throws_ok($$ select public.set_medicine_status(
  (select m.id from public.medicines m join public.drug_registrations r on r.id = m.registration_id
   where r.registration_number = 'DR-TEST-0001'), 'inactive', 'no') $$,
  'P0001', 'REASON_LENGTH', 'too-short reason is refused');

-- A customer can't add registrations
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
select throws_ok($$ select public.admin_save_registration(jsonb_build_object(
  'registration_number', 'DR-TEST-0002', 'generic_name', 'X', 'strength', '1 mg',
  'dosage_form_id', 1)) $$,
  'P0001', 'NOT_ALLOWED', 'customers cannot add registrations');

-- Undo all test data
reset role;
select * from finish();
rollback;