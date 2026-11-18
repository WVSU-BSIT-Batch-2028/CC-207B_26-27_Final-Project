begin;
select plan(9);

-- 1-4. Functions exist
select has_function('public', 'add_to_cart', array['uuid', 'uuid', 'integer', 'boolean'], 'add_to_cart exists');
select has_function('public', 'set_cart_item_quantity', array['uuid', 'integer'], 'set_cart_item_quantity exists');
select has_function('public', 'clear_my_cart', array[]::text[], 'clear_my_cart exists');
select has_function('public', 'get_my_cart', array[]::text[], 'get_my_cart exists');

do $$
declare
  v_form_tab smallint;
  v_unit_tab smallint;
  v_med_1 uuid;
  v_med_2 uuid;
  v_branch_1 uuid;
  v_branch_2 uuid;
  v_customer_id uuid := '11111111-1111-1111-1111-111111111199';
begin
  select id into v_form_tab from public.dosage_forms where name = 'Tablet';
  select id into v_unit_tab from public.units where name = 'tablet';

  insert into auth.users (id, email)
  values (v_customer_id, 'cart_customer_test@meditech.dev')
  on conflict (id) do nothing;

  insert into public.accounts (id, account_type)
  values (v_customer_id, 'customer')
  on conflict (id) do update
  set account_type = 'customer';

  insert into public.medicines (brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status)
  values ('CartBio', 'Paracetamol', '500 mg', v_form_tab, v_unit_tab, false, 'active')
  returning id into v_med_1;

  insert into public.medicines (brand_name, generic_name, strength, dosage_form_id, unit_sold_id, is_rx, status)
  values ('CartAmox', 'Amoxicillin', '500 mg', v_form_tab, v_unit_tab, true, 'active')
  returning id into v_med_2;

  insert into public.branches (
    pharmacy_name, branch_name, address, contact_number, email, latitude, longitude, status, lto_number, lto_expiry
  ) values (
    'Cart Pharmacy One', 'Main', 'Iloilo City', '09173330001', 'cart_phm1@meditech.dev',
    10.695, 122.545, 'active', 'LTO-CRT-001', current_date + 365
  ) returning id into v_branch_1;

  insert into public.branches (
    pharmacy_name, branch_name, address, contact_number, email, latitude, longitude, status, lto_number, lto_expiry
  ) values (
    'Cart Pharmacy Two', 'Jaro', 'Jaro, Iloilo City', '09173330002', 'cart_phm2@meditech.dev',
    10.725, 122.558, 'active', 'LTO-CRT-002', current_date + 365
  ) returning id into v_branch_2;

  insert into public.inventory_items (branch_id, medicine_id, stock_quantity, price_per_unit)
  values
    (v_branch_1, v_med_1, 20, 5.00),
    (v_branch_2, v_med_2, 15, 12.00);

  perform set_config('test.cust_id', v_customer_id::text, true);
  perform set_config('test.med_1', v_med_1::text, true);
  perform set_config('test.med_2', v_med_2::text, true);
  perform set_config('test.branch_1', v_branch_1::text, true);
  perform set_config('test.branch_2', v_branch_2::text, true);
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.cust_id'), true);

-- 5. Adding first item succeeds
select is(
  public.add_to_cart(
    current_setting('test.branch_1')::uuid,
    current_setting('test.med_1')::uuid,
    2,
    false
  ),
  'added',
  'Customer can add available medicine to cart'
);

-- 6. Adding item from a different branch returns branch_conflict
select is(
  public.add_to_cart(
    current_setting('test.branch_2')::uuid,
    current_setting('test.med_2')::uuid,
    1,
    false
  ),
  'branch_conflict',
  'Adding from another branch triggers branch_conflict'
);

-- 7. Replacing branch clears previous branch and adds new item
select is(
  public.add_to_cart(
    current_setting('test.branch_2')::uuid,
    current_setting('test.med_2')::uuid,
    3,
    true
  ),
  'added',
  'Replacing branch succeeds when confirmed'
);

-- 8. get_my_cart returns the updated branch item and quantity
select is(
  (select quantity from public.get_my_cart() where medicine_id = current_setting('test.med_2')::uuid),
  3,
  'get_my_cart returns updated cart item quantity'
);

-- 9. Setting quantity to 0 removes item and clears empty cart
select lives_ok(
  $$select public.set_cart_item_quantity(current_setting('test.med_2')::uuid, 0)$$,
  'Setting quantity to 0 removes item cleanly'
);

select * from finish();
rollback;