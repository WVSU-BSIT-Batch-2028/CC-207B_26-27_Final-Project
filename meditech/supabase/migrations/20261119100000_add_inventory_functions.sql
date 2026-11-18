-- Inventory actions for pharmacy staff: add, edit, out of stock, back in stock,
-- and activate or deactivate a listing

-- =====================================================================
-- Helper: the branch of the signed-in staff member, or an error
-- =====================================================================
create or replace function public._inventory_branch()
returns uuid
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  -- Only pharmacy staff may manage inventory
  if public.my_account_type() is distinct from 'staff' then
    raise exception 'Only pharmacy staff can manage inventory';
  end if;

  v_branch := public.my_branch_id();
  if v_branch is null then
    raise exception 'Your account is not linked to an active branch';
  end if;

  return v_branch;
end
$$;

-- Only used internally by the inventory functions
revoke execute on function public._inventory_branch() from public, anon, authenticated;

-- =====================================================================
-- Helper: write one line in the branch's activity log
-- =====================================================================
create or replace function public._inventory_log(
  p_branch_id uuid, p_action text, p_display_id text, p_details jsonb default '{}'
)
returns void
language sql security definer
set search_path = ''
as $$
  select public.log_activity(
    p_branch_id, auth.uid(), public._staff_label(auth.uid()),
    public.my_staff_role()::text, p_action, 'inventory_item', p_display_id, p_details)
$$;

-- Only used internally by the inventory functions
revoke execute on function public._inventory_log(uuid, text, text, jsonb)
  from public, anon, authenticated;

-- =====================================================================
-- 1. ADD an inventory entry (medicine must come from the catalogue)
-- =====================================================================
create or replace function public.add_inventory_item(
  p_medicine_id uuid,
  p_stock_quantity int,
  p_price_per_unit numeric,
  p_low_stock_threshold int default 10,
  p_nearest_expiry date default null
)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_branch uuid := public._inventory_branch();
  v_id uuid;
  v_display text;
begin
  -- Check the numbers
  if p_stock_quantity is null or p_stock_quantity < 0 then
    raise exception 'Stock quantity must be a whole number of 0 or more';
  end if;
  if p_price_per_unit is null or p_price_per_unit <= 0
     or p_price_per_unit <> round(p_price_per_unit, 2) then
    raise exception 'Price must be above 0 with at most 2 decimal places';
  end if;
  if p_low_stock_threshold is null or p_low_stock_threshold < 1 then
    raise exception 'Low-stock level must be 1 or more';
  end if;

  -- The medicine must be active in the shared catalogue
  if not exists (
    select 1 from public.medicines where id = p_medicine_id and status = 'active'
  ) then
    raise exception 'This medicine is not in the catalogue';
  end if;

  -- One listing per medicine at each branch
  if exists (
    select 1 from public.inventory_items
    where branch_id = v_branch and medicine_id = p_medicine_id
  ) then
    raise exception 'This medicine is already in your inventory';
  end if;

  insert into public.inventory_items
    (branch_id, medicine_id, stock_quantity, price_per_unit,
     low_stock_threshold, nearest_expiry, updated_by)
  values
    (v_branch, p_medicine_id, p_stock_quantity, p_price_per_unit,
     p_low_stock_threshold, p_nearest_expiry, auth.uid())
  returning id, display_id into v_id, v_display;

  perform public._inventory_log(v_branch, 'inventory_added', v_display,
    jsonb_build_object('stock', p_stock_quantity, 'price', p_price_per_unit));

  return v_id;
end
$$;

-- =====================================================================
-- 2. EDIT an entry. Leave p_stock_quantity empty for a price-only edit:
-- only a hand-saved stock count restarts the 7-day Unconfirmed timer.
-- =====================================================================
create or replace function public.update_inventory_item(
  p_item_id uuid,
  p_stock_quantity int default null,
  p_price_per_unit numeric default null,
  p_low_stock_threshold int default null,
  p_nearest_expiry date default null,
  p_clear_expiry boolean default false
)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_branch uuid := public._inventory_branch();
  v_item public.inventory_items%rowtype;
begin
  select * into v_item from public.inventory_items
  where id = p_item_id and branch_id = v_branch
  for update;

  if not found then
    raise exception 'This inventory entry was not found at your branch';
  end if;

  -- Check only the values that were sent
  if p_stock_quantity is not null then
    if p_stock_quantity < 0 then
      raise exception 'Stock quantity must be a whole number of 0 or more';
    end if;
    if p_stock_quantity < v_item.held_quantity then
      raise exception 'Stock cannot be lower than the % units held for reservations',
        v_item.held_quantity;
    end if;
  end if;
  if p_price_per_unit is not null
     and (p_price_per_unit <= 0 or p_price_per_unit <> round(p_price_per_unit, 2)) then
    raise exception 'Price must be above 0 with at most 2 decimal places';
  end if;
  if p_low_stock_threshold is not null and p_low_stock_threshold < 1 then
    raise exception 'Low-stock level must be 1 or more';
  end if;

  update public.inventory_items set
    stock_quantity = coalesce(p_stock_quantity, stock_quantity),
    price_per_unit = coalesce(p_price_per_unit, price_per_unit),
    low_stock_threshold = coalesce(p_low_stock_threshold, low_stock_threshold),
    nearest_expiry = case when p_clear_expiry then null
                          else coalesce(p_nearest_expiry, nearest_expiry) end,
    -- Only a hand-saved stock count restarts the 7-day timer
    stock_confirmed_at = case when p_stock_quantity is not null
                              then now() else stock_confirmed_at end,
    updated_by = auth.uid()
  where id = p_item_id;

  perform public._inventory_log(v_branch, 'inventory_edited', v_item.display_id,
    jsonb_build_object(
      'old_stock', v_item.stock_quantity, 'new_stock', p_stock_quantity,
      'old_price', v_item.price_per_unit, 'new_price', p_price_per_unit));
end
$$;

-- =====================================================================
-- 3. MARK OUT OF STOCK (one or many). The recorded count is kept.
-- =====================================================================
create or replace function public.set_out_of_stock(p_item_ids uuid[])
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_branch uuid := public._inventory_branch();
  v_row record;
  v_wanted int;
  v_done int := 0;
begin
  select count(distinct x) into v_wanted from unnest(p_item_ids) as x;
  if coalesce(v_wanted, 0) = 0 then
    raise exception 'Select at least one medicine';
  end if;

  for v_row in
    update public.inventory_items
    set out_of_stock_flag = true, updated_by = auth.uid()
    where id = any(p_item_ids) and branch_id = v_branch
    returning display_id
  loop
    v_done := v_done + 1;
    perform public._inventory_log(v_branch, 'marked_out_of_stock', v_row.display_id);
  end loop;

  if v_done <> v_wanted then
    raise exception 'Some medicines were not found at your branch';
  end if;
end
$$;

-- =====================================================================
-- 4. BACK IN STOCK. Staff count the shelf; the new number replaces the stock.
-- p_items looks like [{"item_id": "...", "quantity": 8}]
-- =====================================================================
create or replace function public.back_in_stock(p_items jsonb)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_branch uuid := public._inventory_branch();
  v_entry jsonb;
  v_item public.inventory_items%rowtype;
  v_qty int;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Select at least one medicine';
  end if;

  for v_entry in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_entry->>'quantity')::int;

    select * into v_item from public.inventory_items
    where id = (v_entry->>'item_id')::uuid and branch_id = v_branch
    for update;

    if not found then
      raise exception 'Some medicines were not found at your branch';
    end if;
    if v_qty is null or v_qty < 1 then
      raise exception 'Enter the shelf count: a whole number of at least 1';
    end if;
    if v_qty < v_item.held_quantity then
      raise exception 'The count cannot be lower than the % units held for reservations',
        v_item.held_quantity;
    end if;

    -- New count replaces the old one and the switch turns off
    update public.inventory_items set
      stock_quantity = v_qty,
      out_of_stock_flag = false,
      stock_confirmed_at = now(),
      updated_by = auth.uid()
    where id = v_item.id;

    perform public._inventory_log(v_branch, 'back_in_stock', v_item.display_id,
      jsonb_build_object('old_stock', v_item.stock_quantity, 'new_stock', v_qty));
  end loop;
end
$$;

-- =====================================================================
-- 5. ACTIVATE or DEACTIVATE listings (one or many)
-- =====================================================================
create or replace function public.set_listing_active(p_item_ids uuid[], p_active boolean)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_branch uuid := public._inventory_branch();
  v_row record;
  v_wanted int;
  v_done int := 0;
begin
  select count(distinct x) into v_wanted from unnest(p_item_ids) as x;
  if coalesce(v_wanted, 0) = 0 then
    raise exception 'Select at least one medicine';
  end if;

  for v_row in
    update public.inventory_items
    set is_active = p_active, updated_by = auth.uid()
    where id = any(p_item_ids) and branch_id = v_branch
    returning display_id
  loop
    v_done := v_done + 1;
    perform public._inventory_log(v_branch,
      case when p_active then 'listing_activated' else 'listing_deactivated' end,
      v_row.display_id);
  end loop;

  if v_done <> v_wanted then
    raise exception 'Some medicines were not found at your branch';
  end if;
end
$$;

-- Only signed-in users may call the five actions (they check the role inside)
revoke execute on function public.add_inventory_item(uuid, int, numeric, int, date)
  from public, anon;
revoke execute on function public.update_inventory_item(uuid, int, numeric, int, date, boolean)
  from public, anon;
revoke execute on function public.set_out_of_stock(uuid[]) from public, anon;
revoke execute on function public.back_in_stock(jsonb) from public, anon;
revoke execute on function public.set_listing_active(uuid[], boolean) from public, anon;
grant execute on function public.add_inventory_item(uuid, int, numeric, int, date) to authenticated;
grant execute on function public.update_inventory_item(uuid, int, numeric, int, date, boolean) to authenticated;
grant execute on function public.set_out_of_stock(uuid[]) to authenticated;
grant execute on function public.back_in_stock(jsonb) to authenticated;
grant execute on function public.set_listing_active(uuid[], boolean) to authenticated;