begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- An admin and a customer
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'admin.o@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'cust.o@test.com');
insert into public.accounts (id, account_type, username) values
  ('11111111-1111-1111-1111-111111111111', 'admin', 'admin_o'),
  ('22222222-2222-2222-2222-222222222222', 'customer', null);
insert into public.admins (account_id, display_name)
values ('11111111-1111-1111-1111-111111111111', 'Overview Admin');

-- A waiting application to show up in the overview
insert into public.branches
  (pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry)
values ('Farmacia Overview', 'Main', 'Iloilo City', '0333201234', 'o@test.com',
        10.72, 122.56, 'LTO-O-1', '2028-12-31');

-- The admin sees counts and the to-do list
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
select ok((public.admin_overview() ->> 'pending_applications')::int >= 1,
  'overview counts waiting applications');
select ok(exists (
  select 1 from jsonb_array_elements(public.admin_overview() -> 'todo') t
  where t->>'kind' = 'application' and t->>'title' like 'Farmacia Overview%'),
  'the waiting application is on the to-do list');
select ok(public.admin_overview() ? 'open_requests', 'overview includes open requests');

-- A customer gets nothing
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
select is(public.admin_overview(), null, 'customers get no overview');

-- Undo all test data
reset role;
select * from finish();
rollback;