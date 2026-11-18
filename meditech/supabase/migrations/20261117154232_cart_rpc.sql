-- =====================================================================
-- 1. RLS POLICIES FOR CUSTOMER CART TABLES
-- Customers can only read/write their own cart, cart_items, and
-- cart_prescription_files.
-- =====================================================================
create policy "Customers manage own cart" on public.carts
  for all to authenticated
  using (customer_id = auth.uid() and public.my_account_type() = 'customer')
  with check (customer_id = auth.uid() and public.my_account_type() = 'customer');

create policy "Customers manage own cart items" on public.cart_items
  for all to authenticated
  using (customer_id = auth.uid() and public.my_account_type() = 'customer')
  with check (customer_id = auth.uid() and public.my_account_type() = 'customer');

create policy "Customers manage own cart prescriptions" on public.cart_prescription_files
  for all to authenticated
  using (customer_id = auth.uid() and public.my_account_type() = 'customer')
  with check (customer_id = auth.uid() and public.my_account_type() = 'customer');

-- =====================================================================
-- 2. ADD TO CART (ENFORCES SINGLE-BRANCH CART RULE)
-- Returns 'added' when added/incremented, or 'branch_conflict' when
-- the customer already has items from a different branch unless
-- p_replace_branch = true.
-- =====================================================================
create or replace function public.add_to_cart(
  p_branch_id uuid,
  p_medicine_id uuid,
  p_quantity int default 1,
  p_replace_branch boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := auth.uid();
  v_existing_branch_id uuid;
  v_availability public.availability_status;
begin
  if v_customer_id is null or public.my_account_type() <> 'customer' then
    raise exception 'Only signed-in customers can add items to the cart';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Quantity must be at least 1';
  end if;

  -- Verify branch is approved and item is available or low_stock
  select pa.availability into v_availability
  from public.public_availability pa
  where pa.branch_id = p_branch_id
    and pa.medicine_id = p_medicine_id;

  if v_availability is null or v_availability not in ('available', 'low_stock') then
    raise exception 'This medicine is currently unavailable at the selected pharmacy';
  end if;

  select c.branch_id into v_existing_branch_id
  from public.carts c
  where c.customer_id = v_customer_id;

  if v_existing_branch_id is not null and v_existing_branch_id <> p_branch_id then
    if not p_replace_branch then
      return 'branch_conflict';
    end if;

    -- Replace old branch cart
    delete from public.carts where customer_id = v_customer_id;
    v_existing_branch_id := null;
  end if;

  if v_existing_branch_id is null then
    insert into public.carts (customer_id, branch_id)
    values (v_customer_id, p_branch_id);
  end if;

  insert into public.cart_items (customer_id, medicine_id, quantity)
  values (v_customer_id, p_medicine_id, p_quantity)
  on conflict (customer_id, medicine_id)
  do update set quantity = public.cart_items.quantity + excluded.quantity;

  update public.carts
  set updated_at = now()
  where customer_id = v_customer_id;

  return 'added';
end;
$$;

-- =====================================================================
-- 3. UPDATE CART ITEM QUANTITY (REMOVES ITEM WHEN QUANTITY <= 0,
-- AND DELETES CART HEADER WHEN NO ITEMS REMAIN)
-- =====================================================================
create or replace function public.set_cart_item_quantity(
  p_medicine_id uuid,
  p_quantity int
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := auth.uid();
  v_remaining int;
begin
  if v_customer_id is null or public.my_account_type() <> 'customer' then
    raise exception 'Only signed-in customers can update the cart';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    delete from public.cart_items
    where customer_id = v_customer_id
      and medicine_id = p_medicine_id;
  else
    update public.cart_items
    set quantity = p_quantity
    where customer_id = v_customer_id
      and medicine_id = p_medicine_id;
  end if;

  select count(*) into v_remaining
  from public.cart_items
  where customer_id = v_customer_id;

  if v_remaining = 0 then
    delete from public.carts where customer_id = v_customer_id;
  else
    update public.carts
    set updated_at = now()
    where customer_id = v_customer_id;
  end if;
end;
$$;

-- =====================================================================
-- 4. CLEAR CART
-- =====================================================================
create or replace function public.clear_my_cart()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := auth.uid();
begin
  if v_customer_id is null or public.my_account_type() <> 'customer' then
    raise exception 'Only signed-in customers can clear the cart';
  end if;

  delete from public.carts where customer_id = v_customer_id;
end;
$$;

-- =====================================================================
-- 5. GET MY CART ITEMS (JOINED WITH PUBLIC BRANCH & MEDICINE DETAILS)
-- =====================================================================
create or replace function public.get_my_cart()
returns table (
  branch_id uuid,
  pharmacy_name text,
  branch_name text,
  branch_address text,
  medicine_id uuid,
  brand_name text,
  generic_name text,
  strength text,
  dosage_form text,
  unit_sold text,
  is_rx boolean,
  quantity int,
  price_per_unit numeric,
  availability public.availability_status
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.branch_id,
    b.pharmacy_name,
    b.branch_name,
    b.address as branch_address,
    ci.medicine_id,
    m.brand_name,
    m.generic_name,
    m.strength,
    df.name as dosage_form,
    u.name as unit_sold,
    m.is_rx,
    ci.quantity,
    pa.price_per_unit,
    pa.availability
  from public.carts c
  join public.public_branches b on b.id = c.branch_id
  join public.cart_items ci on ci.customer_id = c.customer_id
  join public.medicines m on m.id = ci.medicine_id
  join public.dosage_forms df on df.id = m.dosage_form_id
  join public.units u on u.id = m.unit_sold_id
  left join public.public_availability pa
    on pa.branch_id = c.branch_id and pa.medicine_id = ci.medicine_id
  where c.customer_id = auth.uid()
  order by ci.added_at asc;
$$;

grant execute on function public.add_to_cart(uuid, uuid, int, boolean) to authenticated;
grant execute on function public.set_cart_item_quantity(uuid, int) to authenticated;
grant execute on function public.clear_my_cart() to authenticated;
grant execute on function public.get_my_cart() to authenticated;