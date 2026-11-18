begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

-- An admin, plus two waiting pharmacies with their owners
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'admin.v@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'owner1.v@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'owner2.v@test.com');
insert into public.accounts (id, account_type, username, state) values
  ('11111111-1111-1111-1111-111111111111', 'admin', 'admin_v', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'staff', 'owner1_v', 'pending_approval'),
  ('33333333-3333-3333-3333-333333333333', 'staff', 'owner2_v', 'pending_approval');
insert into public.admins (account_id, display_name)
values ('11111111-1111-1111-1111-111111111111', 'Test Admin');
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Farmacia Uno', 'Main', 'Molo, Iloilo City',
   '0333201234', 'uno.v@test.com', 10.70, 122.54, 'LTO-V-1', '2028-12-31'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Farmacia Dos', 'Main', 'Jaro, Iloilo City',
   '0333201235', 'dos.v@test.com', 10.72, 122.55, 'LTO-V-2', '2028-12-31');
insert into public.staff_members (account_id, branch_id, role, first_name, last_name) values
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner', 'Ana', 'Reyes'),
  ('33333333-3333-3333-3333-333333333333', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'owner', 'Ben', 'Cruz');

-- Act as the admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);

-- No check yet: approval is blocked
select throws_ok($$ select public.approve_application('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  'P0001', 'NEEDS_FDA_CHECK', 'cannot approve without an FDA check');

-- A "not found" check still blocks approval
select lives_ok($$ select public.record_branch_verification('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'not_found') $$,
  'admin records a not-found check');
select throws_ok($$ select public.approve_application('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  'P0001', 'NEEDS_FDA_CHECK', 'not-found check blocks approval');

-- A "matched" check is recorded
select lives_ok($$ select public.record_branch_verification('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'matched', 'Name and address match') $$,
  'admin records a matched check');

-- The LTO number changes after the check: approval is blocked again
reset role;
update public.branches set lto_number = 'LTO-V-1-NEW' where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
set local role authenticated;
select throws_ok($$ select public.approve_application('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  'P0001', 'NEEDS_FDA_CHECK', 'a changed LTO needs a new check');

-- A new matched check on the current details allows approval
select lives_ok($$ select public.record_branch_verification('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'matched') $$,
  'admin re-checks the new LTO');
select lives_ok($$ select public.approve_application('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  'approval works after a current matched check');

-- Approval made the pharmacy live and unlocked the owner, with a notification
reset role;
select is((select status from public.branches where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'active'::public.branch_status, 'pharmacy is now active');
select is((select state from public.accounts where id = '22222222-2222-2222-2222-222222222222'),
  'active'::public.account_state, 'owner account is now active');
select is((select count(*) from public.notifications
           where recipient_id = '22222222-2222-2222-2222-222222222222' and type = 'application_approved'),
  1::bigint, 'owner is notified of approval');

-- Checks are history and can't be edited
select throws_ok($$ update public.verification_checks set result = 'matched' $$,
  'P0001', null, 'checks cannot be edited');

-- A non-admin can't record checks
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333"}', true);
select throws_ok($$ select public.record_branch_verification('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'matched') $$,
  'P0001', 'NOT_ALLOWED', 'non-admin cannot record checks');

-- Rejecting needs a reason of 5 to 200 characters
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
select throws_ok($$ select public.reject_application('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'no') $$,
  'P0001', 'REASON_LENGTH', 'too-short reason is refused');
select lives_ok($$ select public.reject_application('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'The address on your LTO does not match the address you entered.') $$,
  'reject works with a proper reason');

reset role;
select is((select status from public.branches where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  'rejected'::public.branch_status, 'pharmacy is now rejected');

-- Undo all test data
select * from finish();
rollback;