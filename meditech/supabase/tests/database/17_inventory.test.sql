begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

-- =====================================================================
-- TEST DATA SETUP
-- =====================================================================

-- Two pharmacy branches
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status, approved_at)
values
  ('b2000000-0000-0000-0000-000000000001', 'Inv Pharmacy', 'Main',
   '1 Inv St, Test City', '0330000011', 'inv1@pharmacy.com',
   10.7202, 122.5621, 'INV-LTO-0001', '2028-12-31', 'active', now()),
  ('b2000000-0000-0000-0000-000000000002', 'Other Pharmacy', 'Other',
   '2 Inv St, Test City', '0330000012', 'inv2@pharmacy.com',
   10.7210, 122.5630, 'INV-LTO-0002', '2028-12-31', 'active', now());

-- Staff at branch 1 and branch 2
insert into auth.users (id, email) values
  ('b3000000-0000-0000-0000-000000000001', 'inv.staff@test.com'),
  ('b3000000-0000-0000-0000-000000000002', 'inv.other@test.com'),
  ('b1000000-0000-0000-0000-000000000001', 'inv.customer@test.com');
insert into public.accounts (id, account_type) values
  ('b3000000-0000-0000-0000-000000000001', 'staff'),
  ('b3000000-0000-0000-0000-000000000002', 'staff'),
  ('b1000000-0000-0000-0000-000000000001', 'customer');
insert into public.staff_members (account_id, branch_id, role, first_name, last_name)
values
  ('b3000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001',
   'staff', 'Inv', 'Staff'),
  ('b3000000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000002',
   'staff', 'Other', 'Staff');
insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values
  ('b1000000-0000-0000-0000-000000000001', 'Inv', 'Customer', '09990000011',
   'inv.customer@test.com', '1995-01-01', 'v1');

-- Three medicines: two active, one inactive
insert into public.medicines
  (id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id, status)
values
  ('b5000000-0000-0000-0000-000000000001', 'InvMedA', 'GenA', '500 mg',
   (select id from public.dosage_forms where name = 'Tablet'),
   (select id from public.units where name = 'tablet'), 'active'),
  ('b5000000-0000-0000-0000-000000000002', 'InvMedB', 'GenB', '250 mg',
   (select id from public.dosage_forms where name = 'Capsule'),
   (select id from public.units where name = 'capsule'), 'active'),
  ('b5000000-0000-0000-0000-000000000003', 'InvMedOld', 'GenOld', '10 mg',
   (select id from public.dosage_forms where name = 'Tablet'),
   (select id from public.units where name = 'tablet'), 'inactive');

-- One existing listing at branch 1 (20 units held) and one at branch 2
insert into public.inventory_items
  (id, branch_id, medicine_id, stock_quantity, held_quantity, price_per_unit)
values
  ('b6000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001',
   'b5000000-0000-0000-0000-000000000001', 100, 20, 5.00),
  ('b6000000-0000-0000-0000-000000000009', 'b2000000-0000-0000-0000-000000000002',
   'b5000000-0000-0000-0000-000000000001', 50, 0, 6.00);

-- Helpers to switch the signed-in user
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
-- 1. THE FUNCTIONS EXIST
-- =====================================================================
select has_function('public', 'add_inventory_item', 'add_inventory_item exists');
select has_function('public', 'update_inventory_item', 'update_inventory_item exists');
select has_function('public', 'set_out_of_stock', 'set_out_of_stock exists');
select has_function('public', 'back_in_stock', 'back_in_stock exists');
select has_function('public', 'set_listing_active', 'set_listing_active exists');

-- =====================================================================
-- 2. ADD
-- =====================================================================
select set_auth_user('b3000000-0000-0000-0000-000000000001');

select lives_ok(
  $$ select public.add_inventory_item('b5000000-0000-0000-0000-000000000002', 30, 12.50, 5) $$,
  'staff can add a catalogue medicine');

select throws_ok(
  $$ select public.add_inventory_item('b5000000-0000-0000-0000-000000000002', 30, 12.50) $$,
  'P0001', 'This medicine is already in your inventory', 'duplicate listing is refused');

select throws_ok(
  $$ select public.add_inventory_item('b5000000-0000-0000-0000-000000000003', 30, 5.00) $$,
  'P0001', 'This medicine is not in the catalogue', 'inactive medicine is refused');

select throws_ok(
  $$ select public.add_inventory_item('b5000000-0000-0000-0000-000000000001', 30, 4.555) $$,
  'P0001', 'Price must be above 0 with at most 2 decimal places',
  'price with 3 decimals is refused');

-- =====================================================================
-- 3. EDIT AND THE 7-DAY TIMER
-- =====================================================================

-- Make the stock count look old, then edit the price only
select reset_auth();
update public.inventory_items set stock_confirmed_at = now() - interval '10 days'
where id = 'b6000000-0000-0000-0000-000000000001';
select set_auth_user('b3000000-0000-0000-0000-000000000001');

select lives_ok(
  $$ select public.update_inventory_item('b6000000-0000-0000-0000-000000000001',
       null, 5.25) $$,
  'staff can edit the price only');

select reset_auth();
select ok(
  (select stock_confirmed_at < now() - interval '9 days'
   from public.inventory_items where id = 'b6000000-0000-0000-0000-000000000001'),
  'a price-only edit does not restart the 7-day timer');
select set_auth_user('b3000000-0000-0000-0000-000000000001');

select throws_ok(
  $$ select public.update_inventory_item('b6000000-0000-0000-0000-000000000001', 10) $$,
  'P0001', null, 'stock below the held units is refused');

select lives_ok(
  $$ select public.update_inventory_item('b6000000-0000-0000-0000-000000000001', 90) $$,
  'a hand-saved stock count is accepted');

select reset_auth();
select ok(
  (select stock_confirmed_at > now() - interval '1 minute'
   from public.inventory_items where id = 'b6000000-0000-0000-0000-000000000001'),
  'a stock edit restarts the 7-day timer');
select set_auth_user('b3000000-0000-0000-0000-000000000001');

-- =====================================================================
-- 4. OUT OF STOCK AND BACK IN STOCK
-- =====================================================================
select lives_ok(
  $$ select public.set_out_of_stock(array['b6000000-0000-0000-0000-000000000001']::uuid[]) $$,
  'staff can mark out of stock');

select reset_auth();
select is(
  (select stock_quantity from public.inventory_items
   where id = 'b6000000-0000-0000-0000-000000000001'), 90,
  'marking out of stock keeps the recorded count');
select set_auth_user('b3000000-0000-0000-0000-000000000001');

select throws_ok(
  $$ select public.back_in_stock('[{"item_id":"b6000000-0000-0000-0000-000000000001","quantity":5}]'::jsonb) $$,
  'P0001', null, 'back in stock below the held units is refused');

select lives_ok(
  $$ select public.back_in_stock('[{"item_id":"b6000000-0000-0000-0000-000000000001","quantity":40}]'::jsonb) $$,
  'back in stock with a shelf count works');

select reset_auth();
select ok(
  (select not out_of_stock_flag and stock_quantity = 40
   from public.inventory_items where id = 'b6000000-0000-0000-0000-000000000001'),
  'back in stock replaces the count and turns the switch off');
select set_auth_user('b3000000-0000-0000-0000-000000000001');

-- =====================================================================
-- 5. ACCESS: OTHER BRANCH AND CUSTOMERS ARE REFUSED
-- =====================================================================
select throws_ok(
  $$ select public.set_listing_active(array['b6000000-0000-0000-0000-000000000009']::uuid[], false) $$,
  'P0001', 'Some medicines were not found at your branch',
  'another branch''s listing is refused');

select set_auth_user('b1000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.add_inventory_item('b5000000-0000-0000-0000-000000000001', 10, 5.00) $$,
  'P0001', 'Only pharmacy staff can manage inventory',
  'a customer cannot add inventory');

select reset_auth();
select * from finish();
rollback;