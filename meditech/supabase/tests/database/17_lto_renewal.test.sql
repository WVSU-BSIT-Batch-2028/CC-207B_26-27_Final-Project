begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- An approved pharmacy with an owner and a staff member, a second pharmacy, and an admin
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Farmacia Renew', 'Main', 'Iloilo City',
   '0333201234', 'renew@test.com', 10.72, 122.56, 'LTO-RN-OLD', '2028-12-31', 'active'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Farmacia Soon', 'Main', 'Iloilo City',
   '0333201235', 'soon@test.com', 10.73, 122.57, 'LTO-RN-SOON', current_date + 10, 'active');
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner.rn@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'staff.rn@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'admin.rn@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'owner2.rn@test.com');
insert into public.accounts (id, account_type, username) values
  ('11111111-1111-1111-1111-111111111111', 'staff', 'owner_rn'),
  ('22222222-2222-2222-2222-222222222222', 'staff', 'staff_rn'),
  ('33333333-3333-3333-3333-333333333333', 'admin', 'admin_rn'),
  ('44444444-4444-4444-4444-444444444444', 'staff', 'owner2_rn');
insert into public.staff_members (account_id, branch_id, role, first_name, last_name) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner', 'Rina', 'Santos'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'staff', 'Leo', 'Cruz'),
  ('44444444-4444-4444-4444-444444444444', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'owner', 'Mia', 'Tan');
insert into public.admins (account_id, display_name)
values ('33333333-3333-3333-3333-333333333333', 'Renewal Admin');

-- The admin deactivates the pharmacy (Kim's function)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', true);
select public.deactivate_branch('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'The LTO has expired.');
reset role;

-- The owner is suspended and told why
select is((select state from public.accounts where id = '11111111-1111-1111-1111-111111111111'),
  'suspended'::public.account_state, 'owner is suspended when the pharmacy goes offline');
select is((select count(*) from public.notifications
           where recipient_id = '11111111-1111-1111-1111-111111111111' and type = 'branch_deactivated'),
  1::bigint, 'owner is notified with the reason');

-- Staff can't sign in; the owner still can
select ok(public.custom_access_token_hook(jsonb_build_object(
  'user_id', '22222222-2222-2222-2222-222222222222', 'claims', '{}'::jsonb)) ? 'error',
  'staff of an offline pharmacy cannot sign in');
select ok(not (public.custom_access_token_hook(jsonb_build_object(
  'user_id', '11111111-1111-1111-1111-111111111111', 'claims', '{}'::jsonb)) ? 'error'),
  'the suspended owner can still sign in');

-- The owner sends a renewal
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
select throws_ok($$ select public.submit_lto_renewal(jsonb_build_object(
  'lto_number', 'LTO-RN-NEW', 'lto_expiry', '2020-01-01',
  'storage_path', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/lto_renewal/x.pdf',
  'mime_type', 'application/pdf', 'size_bytes', 1000)) $$,
  'P0001', 'LTO_EXPIRED', 'an expired renewal is refused');
select lives_ok($$ select public.submit_lto_renewal(jsonb_build_object(
  'lto_number', 'LTO-RN-NEW', 'lto_expiry', '2031-12-31',
  'storage_path', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/lto_renewal/x.pdf',
  'mime_type', 'application/pdf', 'size_bytes', 1000)) $$,
  'owner sends a renewed LTO');
select throws_ok($$ select public.submit_lto_renewal(jsonb_build_object(
  'lto_number', 'LTO-RN-NEWER', 'lto_expiry', '2031-12-31',
  'storage_path', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/lto_renewal/y.pdf',
  'mime_type', 'application/pdf', 'size_bytes', 1000)) $$,
  '23505', null, 'only one renewal can wait at a time');

-- The admin accepts it; the pharmacy carries the new license
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', true);
select lives_ok($$ select public.review_lto_renewal(
  (select id from public.lto_renewals where lto_number = 'LTO-RN-NEW'), true) $$,
  'admin accepts the renewal');
reset role;
select is((select lto_number from public.branches where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'LTO-RN-NEW', 'pharmacy now has the renewed LTO number');

-- Reactivating unsuspends the owner (Kim's function)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', true);
select public.activate_branch('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
reset role;
select is((select state from public.accounts where id = '11111111-1111-1111-1111-111111111111'),
  'active'::public.account_state, 'owner is active again after reactivation');

-- The expiry reminder reaches the other owner once, not twice
select ok(public.send_lto_expiry_reminders() >= 1, 'reminder is sent for an LTO expiring soon');
select is(public.send_lto_expiry_reminders(), 0, 'the same reminder is not sent twice');

-- Undo all test data
select * from finish();
rollback;