begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

-- An admin, a customer, and an applicant owner
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'admin.t@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'cust.t@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'owner.t@test.com');
insert into public.accounts (id, account_type, username, state) values
  ('11111111-1111-1111-1111-111111111111', 'admin', 'admin_t', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'customer', null, 'active'),
  ('33333333-3333-3333-3333-333333333333', 'staff', 'owner_t', 'pending_approval');
insert into public.admins (account_id, display_name)
values ('11111111-1111-1111-1111-111111111111', 'Test Admin');

-- A waiting application with hours, an owner, and two documents
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Farmacia Prueba', 'Main Branch',
   '1 Test St, Iloilo City', '0333201234', 'prueba@test.com',
   10.72, 122.56, 'LTO-TEST-ADMIN', '2028-12-31');
insert into public.branch_hours (branch_id, weekday, opens_at, closes_at)
select 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', d, '08:00', '20:00' from generate_series(0, 6) d;
insert into public.staff_members (account_id, branch_id, role, first_name, last_name, mobile)
values ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'owner', 'Ana', 'Reyes', '09171234567');
insert into public.branch_documents (branch_id, kind, storage_path, mime_type, size_bytes)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'lto', 'aaaa/lto/x.pdf', 'application/pdf', 1000),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'storefront', 'aaaa/storefront/y.jpg', 'image/jpeg', 2000);

-- Act as the admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);

-- The admin sees the application in the list, with the owner's name
select is((select owner_name from public.admin_list_pharmacies()
           where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Ana Reyes', 'admin sees the application with the owner name');

-- Search and status filter work
select is((select count(*) from public.admin_list_pharmacies(null, 'prueba')), 1::bigint,
  'search by pharmacy name finds it');
select is((select count(*) from public.admin_list_pharmacies('active', 'prueba')), 0::bigint,
  'status filter leaves it out of Active');

-- The details include hours, owner, and documents
select is(jsonb_array_length(public.admin_get_application('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') -> 'hours'),
  7, 'details include all 7 days of hours');
select is(public.admin_get_application('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') -> 'owner' ->> 'mobile',
  '09171234567', 'details include the owner mobile');
select is(jsonb_array_length(public.admin_get_application('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') -> 'documents'),
  2, 'details include both documents');

-- A customer gets nothing
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
select is((select count(*) from public.admin_list_pharmacies()), 0::bigint,
  'customer sees no pharmacies');
select is(public.admin_get_application('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'), null,
  'customer cannot open an application');

-- Undo all test data
reset role;
select * from finish();
rollback;