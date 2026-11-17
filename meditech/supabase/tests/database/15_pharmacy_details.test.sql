begin;
select plan(9);

-- 1-3. Functions exist
select has_function(
  'public',
  'get_pharmacy_details',
  array['uuid', 'numeric', 'numeric'],
  'get_pharmacy_details function exists'
);

select has_function(
  'public',
  'get_pharmacy_hours',
  array['uuid'],
  'get_pharmacy_hours function exists'
);

select has_function(
  'public',
  'get_pharmacy_inventory',
  array['uuid', 'text'],
  'get_pharmacy_inventory function exists'
);

-- Seed isolated fixtures and store IDs in session settings for anon assertions
do $$
declare
  v_form_tab smallint;
  v_unit_tab smallint;
  v_med_1 uuid;
  v_med_2 uuid;
  v_branch_active uuid;
  v_branch_pending uuid;
begin
  select id into v_form_tab from public.dosage_forms where name = 'Tablet';
  select id into v_unit_tab from public.units where name = 'tablet';

  insert into public.medicines (brand_name, generic_name, strength, dosage_form_id, unit_sold_id, pack_description, is_rx, status)
  values ('PharmTestBio', 'PharmTestPara', '500 mg', v_form_tab, v_unit_tab, 'Box of 100 tablets', false, 'active')
  returning id into v_med_1;

  insert into public.medicines (brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status)
  values ('PharmTestLosartan', 'Losartan Potassium', '50 mg', v_form_tab, v_unit_tab, true, 'active')
  returning id into v_med_2;

  insert into public.branches (
    pharmacy_name, branch_name, address, contact_number, email, latitude, longitude, status, lto_number, lto_expiry
  ) values (
    'Mercury Test Drug', 'Molo Plaza', 'Molo Plaza, Iloilo City', '09172220001', 'molo_test@meditech.dev',
    10.695000, 122.545000, 'active', 'LTO-PHM-101', current_date + 365
  ) returning id into v_branch_active;

  insert into public.branches (
    pharmacy_name, branch_name, address, contact_number, email, latitude, longitude, status, lto_number, lto_expiry
  ) values (
    'Pending Test Pharmacy', 'Jaro', 'Jaro, Iloilo City', '09172220002', 'pending_test@meditech.dev',
    10.725000, 122.558000, 'pending_approval', 'LTO-PHM-102', current_date + 365
  ) returning id into v_branch_pending;

  insert into public.branch_hours (branch_id, weekday, opens_at, closes_at, is_closed)
  values
    (v_branch_active, 0, null, null, true),
    (v_branch_active, 1, '08:00', '20:00', false);

  insert into public.inventory_items (branch_id, medicine_id, stock_quantity, price_per_unit)
  values
    (v_branch_active, v_med_1, 30, 5.50),
    (v_branch_active, v_med_2, 0, 12.00),
    (v_branch_pending, v_med_1, 50, 4.00);

  perform set_config('test.active_branch_id', v_branch_active::text, true);
  perform set_config('test.pending_branch_id', v_branch_pending::text, true);
end $$;

set local role anon;

-- 4. Active branch details are returned to guests
select is(
  (
    select pharmacy_name
    from public.get_pharmacy_details(
      current_setting('test.active_branch_id')::uuid
    )
  ),
  'Mercury Test Drug',
  'Guest can fetch approved pharmacy details'
);

-- 5. Pending branch details are hidden
select is(
  (
    select count(*)
    from public.get_pharmacy_details(
      current_setting('test.pending_branch_id')::uuid
    )
  ),
  0::bigint,
  'Pending branches are excluded from get_pharmacy_details'
);

-- 6. Opening hours return in weekday order
select is(
  (
    select is_closed
    from public.get_pharmacy_hours(
      current_setting('test.active_branch_id')::uuid
    )
    where weekday = 0
  ),
  true,
  'get_pharmacy_hours returns closed status for Sunday'
);

-- 7. Inventory lists all active offerings at the branch
select is(
  (
    select count(*)
    from public.get_pharmacy_inventory(
      current_setting('test.active_branch_id')::uuid
    )
  ),
  2::bigint,
  'get_pharmacy_inventory returns active medicines carried by branch'
);

-- 8. Zero-stock item reports unavailable availability label
select is(
  (
    select availability::text
    from public.get_pharmacy_inventory(
      current_setting('test.active_branch_id')::uuid
    )
    where brand_name = 'PharmTestLosartan'
  ),
  'unavailable',
  'Zero-stock item reports unavailable status'
);

-- 9. Query filter narrows branch medicine list
select is(
  (
    select count(*)
    from public.get_pharmacy_inventory(
      current_setting('test.active_branch_id')::uuid,
      'Losartan'
    )
  ),
  1::bigint,
  'get_pharmacy_inventory filters medicines by search query'
);

select * from finish();
rollback;