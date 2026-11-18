begin;
select plan(10);

-- 1. Functions exist and are callable
select has_function(
  'public',
  'search_medicines',
  array['text', 'text', 'text', 'text', 'text', 'numeric', 'numeric'],
  'search_medicines function exists'
);

select has_function(
  'public',
  'get_medicine_offers',
  array['uuid', 'text', 'numeric', 'numeric'],
  'get_medicine_offers function exists'
);

-- Set up isolated test fixtures
do $$
declare
  v_form_tab smallint;
  v_form_cap smallint;
  v_unit_tab smallint;
  v_unit_cap smallint;
  v_med_active uuid;
  v_med_inactive uuid;
  v_branch_active_1 uuid;
  v_branch_active_2 uuid;
  v_branch_pending uuid;
begin
  select id into v_form_tab from public.dosage_forms where name = 'Tablet';
  select id into v_form_cap from public.dosage_forms where name = 'Capsule';
  select id into v_unit_tab from public.units where name = 'tablet';
  select id into v_unit_cap from public.units where name = 'capsule';

  insert into public.medicines (brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status)
  values ('TestBiogesic', 'TestParacetamol', '500 mg', v_form_tab, v_unit_tab, false, 'active')
  returning id into v_med_active;

  insert into public.medicines (brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status)
  values ('TestHiddenMed', 'TestHiddenGeneric', '250 mg', v_form_cap, v_unit_cap, true, 'inactive')
  returning id into v_med_inactive;

  insert into public.branches (
    pharmacy_name, branch_name, address, contact_number, email, latitude, longitude, status, lto_number, lto_expiry
  ) values (
    'Test Pharmacy La Paz', 'La Paz', 'Luna St, La Paz, Iloilo City', '09171110001', 'lapaz_test@meditech.dev',
    10.710000, 122.570000, 'active', 'LTO-TEST-001', current_date + 365
  ) returning id into v_branch_active_1;

  insert into public.branches (
    pharmacy_name, branch_name, address, contact_number, email, latitude, longitude, status, lto_number, lto_expiry
  ) values (
    'Test Pharmacy Jaro', 'Jaro', 'Lopez Jaena St, Jaro, Iloilo City', '09171110002', 'jaro_test@meditech.dev',
    10.725000, 122.558000, 'active', 'LTO-TEST-002', current_date + 365
  ) returning id into v_branch_active_2;

  insert into public.branches (
    pharmacy_name, branch_name, address, contact_number, email, latitude, longitude, status, lto_number, lto_expiry
  ) values (
    'Test Pending Pharmacy', 'Molo', 'Molo, Iloilo City', '09171110003', 'molo_test@meditech.dev',
    10.695000, 122.545000, 'pending_approval', 'LTO-TEST-003', current_date + 365
  ) returning id into v_branch_pending;

  -- Active listings on active branches with different prices
  insert into public.inventory_items (branch_id, medicine_id, stock_quantity, price_per_unit, low_stock_threshold)
  values
    (v_branch_active_1, v_med_active, 50, 5.00, 10),
    (v_branch_active_2, v_med_active, 5, 4.25, 10);

  -- Inactive listing & pending branch listing (must be excluded from customer search)
  insert into public.inventory_items (branch_id, medicine_id, stock_quantity, price_per_unit, is_active)
  values
    (v_branch_pending, v_med_active, 100, 2.00, true),
    (v_branch_active_1, v_med_inactive, 40, 10.00, true);
end $$;

-- Run tests as an anonymous guest
set local role anon;

-- 3. Search by brand name returns active medicine with lowest active price and 2 pharmacies
select is(
  (select lowest_price from public.search_medicines(p_query => 'TestBiogesic') where brand_name = 'TestBiogesic'),
  4.25,
  'Guest search by brand returns lowest price from active approved pharmacies only'
);

select is(
  (select pharmacy_count from public.search_medicines(p_query => 'TestBiogesic') where brand_name = 'TestBiogesic'),
  2::bigint,
  'Guest search excludes pending pharmacies from pharmacy count'
);

-- 4. Search by generic name finds the same medicine
select is(
  (select count(*) from public.search_medicines(p_query => 'TestParacetamol') where brand_name = 'TestBiogesic'),
  1::bigint,
  'Guest search matches generic name'
);

-- 5. Inactive medicines are never returned
select is(
  (select count(*) from public.search_medicines(p_query => 'TestHiddenMed')),
  0::bigint,
  'Inactive catalogue medicines are excluded from search'
);

-- 6. Dosage form filter works
select is(
  (select count(*) from public.search_medicines(p_query => 'TestBiogesic', p_dosage_form => 'Capsule')),
  0::bigint,
  'Dosage form filter excludes non-matching forms'
);

-- 7. Location filter narrows pharmacy count and updates lowest price
select is(
  (select lowest_price from public.search_medicines(p_query => 'TestBiogesic', p_location => 'La Paz') where brand_name = 'TestBiogesic'),
  5.00,
  'Location filter recalculates lowest price for matching area'
);

-- 8. get_medicine_offers returns offers sorted by price ascending by default
select is(
  (
    select pharmacy_name
    from public.get_medicine_offers(
      (select id from public.medicines where brand_name = 'TestBiogesic')
    )
    limit 1
  ),
  'Test Pharmacy Jaro',
  'get_medicine_offers orders lowest price first by default'
);

-- 9. get_medicine_offers exposes availability label (low_stock) without exposing pending branches
select is(
  (
    select availability::text
    from public.get_medicine_offers(
      (select id from public.medicines where brand_name = 'TestBiogesic')
    )
    where pharmacy_name = 'Test Pharmacy Jaro'
  ),
  'low_stock',
  'get_medicine_offers returns computed availability label'
);

select * from finish();
rollback;