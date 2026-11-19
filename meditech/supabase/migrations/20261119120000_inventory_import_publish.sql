
-- Day 5: Secure inventory import review, publish, and discard operations.
-- All live inventory changes happen inside publish_import.
-- The signed-in staff member's branch is always derived from their session.

begin;

alter table public.inventory_import_rows
  drop constraint inventory_import_rows_stock_check,
  drop constraint inventory_import_rows_price_check,
  drop constraint inventory_import_rows_threshold_check;
-- =====================================================================
-- 1. EDIT ONE STAGED IMPORT ROW
-- =====================================================================

create or replace function public.update_inventory_import_row(
  p_row_id uuid,
  p_medicine_label text,
  p_stock_quantity integer,
  p_price_per_unit numeric,
  p_low_stock_threshold integer default null,
  p_nearest_expiry date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_batch_id uuid;
  v_medicine_id uuid;
  v_match_count integer;
  v_errors text[] := array[]::text[];
  v_total integer;
  v_valid integer;
begin
  v_branch_id := public._inventory_branch();

  -- Find and lock the batch belonging to this staff member's branch.
  select r.batch_id
    into v_batch_id
  from public.inventory_import_rows r
  join public.inventory_import_batches b on b.id = r.batch_id
  where r.id = p_row_id
    and b.branch_id = v_branch_id
    and b.status = 'reviewing';

  if v_batch_id is null then
    raise exception 'Import row not found or is no longer editable';
  end if;

  perform 1
  from public.inventory_import_batches b
  where b.id = v_batch_id
    and b.branch_id = v_branch_id
    and b.status = 'reviewing'
  for update;

  if not found then
    raise exception 'Import batch is no longer available for editing';
  end if;

  -- Match the entered brand + strength against active catalogue entries.
  select count(*), (array_agg(m.id))[1]
    into v_match_count, v_medicine_id
  from public.medicines m
  where m.status = 'active'
    and regexp_replace(
      lower(trim(m.brand_name || ' ' || m.strength)),
      '\s+', ' ', 'g'
    ) = regexp_replace(
      lower(trim(coalesce(p_medicine_label, ''))),
      '\s+', ' ', 'g'
    );

  if trim(coalesce(p_medicine_label, '')) = '' then
    v_errors := array_append(v_errors, 'Medicine is required');
  elsif v_match_count = 0 then
    v_errors := array_append(v_errors, 'Medicine was not found in the active catalogue');
  elsif v_match_count > 1 then
    v_errors := array_append(v_errors, 'Medicine name matches more than one catalogue entry');
  end if;

  if p_stock_quantity is null then
    v_errors := array_append(v_errors, 'Stock quantity is required');
  elsif p_stock_quantity < 0 then
    v_errors := array_append(v_errors, 'Stock quantity cannot be negative');
  end if;

  if p_price_per_unit is null then
    v_errors := array_append(v_errors, 'Price per unit is required');
  elsif p_price_per_unit <= 0 then
    v_errors := array_append(v_errors, 'Price per unit must be greater than zero');
  end if;

  if p_low_stock_threshold is not null
     and p_low_stock_threshold < 1 then
    v_errors := array_append(v_errors, 'Low-stock threshold must be at least 1');
  end if;

  update public.inventory_import_rows
  set
    medicine_label = trim(p_medicine_label),
    stock_quantity = p_stock_quantity,
    price_per_unit = p_price_per_unit,
    low_stock_threshold = p_low_stock_threshold,
    nearest_expiry = p_nearest_expiry,
    matched_medicine_id =
      case when v_match_count = 1 then v_medicine_id else null end,
    errors = v_errors,
    updated_at = now()
  where id = p_row_id
    and batch_id = v_batch_id;

  -- Recalculate the batch's review counts.
  select
    count(*)::integer,
    count(*) filter (
      where cardinality(r.errors) = 0
        and r.matched_medicine_id is not null
    )::integer
  into v_total, v_valid
  from public.inventory_import_rows r
  where r.batch_id = v_batch_id;

  update public.inventory_import_batches
  set
    total_rows = v_total,
    valid_rows = v_valid,
    error_rows = v_total - v_valid,
    updated_at = now()
  where id = v_batch_id;

  return jsonb_build_object(
    'row_id', p_row_id,
    'valid', cardinality(v_errors) = 0 and v_match_count = 1,
    'errors', to_jsonb(v_errors)
  );
end;
$$;


-- =====================================================================
-- 2. REMOVE ONE STAGED IMPORT ROW
-- =====================================================================

create or replace function public.remove_inventory_import_row(
  p_row_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_batch_id uuid;
  v_total integer;
  v_valid integer;
begin
  v_branch_id := public._inventory_branch();

  select r.batch_id
    into v_batch_id
  from public.inventory_import_rows r
  join public.inventory_import_batches b on b.id = r.batch_id
  where r.id = p_row_id
    and b.branch_id = v_branch_id
    and b.status = 'reviewing';

  if v_batch_id is null then
    raise exception 'Import row not found or is no longer editable';
  end if;

  perform 1
  from public.inventory_import_batches b
  where b.id = v_batch_id
    and b.branch_id = v_branch_id
    and b.status = 'reviewing'
  for update;

  if not found then
    raise exception 'Import batch is no longer editable';
  end if;

  delete from public.inventory_import_rows
  where id = p_row_id
    and batch_id = v_batch_id;

  select
    count(*)::integer,
    count(*) filter (
      where cardinality(r.errors) = 0
        and r.matched_medicine_id is not null
    )::integer
  into v_total, v_valid
  from public.inventory_import_rows r
  where r.batch_id = v_batch_id;

  update public.inventory_import_batches
  set
    total_rows = v_total,
    valid_rows = v_valid,
    error_rows = v_total - v_valid,
    updated_at = now()
  where id = v_batch_id;

  return jsonb_build_object(
    'removed', true,
    'total_rows', v_total,
    'valid_rows', v_valid,
    'error_rows', v_total - v_valid
  );
end;
$$;


-- =====================================================================
-- 3. PUBLISH AN ENTIRE IMPORT BATCH ATOMICALLY
-- =====================================================================

create or replace function public.publish_import(
  p_batch_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_total integer;
  v_valid integer;
  v_error integer;
  v_inserted integer;
  v_updated integer;
begin
  v_branch_id := public._inventory_branch();

  -- Lock the batch so two publish attempts cannot run concurrently.
  perform 1
  from public.inventory_import_batches b
  where b.id = p_batch_id
    and b.branch_id = v_branch_id
    and b.status = 'reviewing'
  for update;

  if not found then
    raise exception 'Import batch not found or has already been processed';
  end if;

  select
    count(*)::integer,
    count(*) filter (
      where cardinality(r.errors) = 0
        and r.matched_medicine_id is not null
        and r.stock_quantity is not null
        and r.price_per_unit is not null
        and r.price_per_unit > 0
        and (r.low_stock_threshold is null or r.low_stock_threshold >= 1)
    )::integer
  into v_total, v_valid
  from public.inventory_import_rows r
  where r.batch_id = p_batch_id;

  v_error := v_total - v_valid;

  if v_total = 0 then
    raise exception 'There are no rows to publish';
  end if;

  if v_error > 0 then
    raise exception 'Cannot publish: % row(s) still contain errors', v_error;
  end if;

  -- Every matched medicine must still be active.
  if exists (
    select 1
    from public.inventory_import_rows r
    join public.medicines m on m.id = r.matched_medicine_id
    where r.batch_id = p_batch_id
      and m.status <> 'active'
  ) then
    raise exception 'A matched medicine is no longer active in the catalogue';
  end if;

  -- Do not allow two rows for the same medicine in one import.
  if exists (
    select r.matched_medicine_id
    from public.inventory_import_rows r
    where r.batch_id = p_batch_id
    group by r.matched_medicine_id
    having count(*) > 1
  ) then
    raise exception 'The import contains duplicate medicine entries';
  end if;

  -- Reject the entire import if any new stock quantity would be
  -- lower than the quantity already held for reservations.
  if exists (
    select 1
    from public.inventory_import_rows r
    join public.inventory_items i
      on i.branch_id = v_branch_id
     and i.medicine_id = r.matched_medicine_id
    where r.batch_id = p_batch_id
      and i.held_quantity > r.stock_quantity
  ) then
    raise exception 'Import would reduce stock below units held for reservations';
  end if;

  -- Count new and existing inventory listings before applying changes.
  select count(*)::integer
    into v_updated
  from public.inventory_import_rows r
  join public.inventory_items i
    on i.branch_id = v_branch_id
   and i.medicine_id = r.matched_medicine_id
  where r.batch_id = p_batch_id;

  v_inserted := v_total - v_updated;

  -- Insert new listings or update existing listings.
  -- IMPORTANT:
  -- out_of_stock_flag is deliberately not included in the UPDATE.
  -- Existing held_quantity and is_active values are also preserved.
  insert into public.inventory_items (
    branch_id,
    medicine_id,
    stock_quantity,
    price_per_unit,
    low_stock_threshold,
    nearest_expiry,
    stock_confirmed_at,
    updated_by
  )
  select
    v_branch_id,
    r.matched_medicine_id,
    r.stock_quantity,
    r.price_per_unit,
    coalesce(r.low_stock_threshold, 10),
    r.nearest_expiry,
    now(),
    auth.uid()
  from public.inventory_import_rows r
  where r.batch_id = p_batch_id
  on conflict (branch_id, medicine_id)
  do update set
    stock_quantity = excluded.stock_quantity,
    price_per_unit = excluded.price_per_unit,
    low_stock_threshold = excluded.low_stock_threshold,
    nearest_expiry = excluded.nearest_expiry,
    stock_confirmed_at = now(),
    updated_by = auth.uid(),
    updated_at = now();

  -- Mark the batch as published.
  update public.inventory_import_batches
  set
    status = 'published',
    published_at = now(),
    updated_at = now(),
    total_rows = v_total,
    valid_rows = v_valid,
    error_rows = 0
  where id = p_batch_id;

  -- Record the import in the activity log.
  -- This avoids the existing log_activity() parameter mismatch.
  insert into public.activity_log (
    branch_id,
    actor_id,
    actor_label,
    actor_role,
    action,
    entity_type,
    entity_id,
    details
  )
  values (
    v_branch_id,
    auth.uid(),
    coalesce(
      public._staff_label(auth.uid()),
      'Pharmacy staff'
    ),
    public.my_staff_role()::text,
    'inventory_import_published',
    'inventory_import_batch',
    p_batch_id::text,
    jsonb_build_object(
      'total_rows', v_total,
      'inserted_rows', v_inserted,
      'updated_rows', v_updated
    )
  );

  return jsonb_build_object(
    'published', true,
    'batch_id', p_batch_id,
    'total_rows', v_total,
    'inserted_rows', v_inserted,
    'updated_rows', v_updated
  );
end;
$$;


-- =====================================================================
-- 4. DISCARD AN IMPORT BATCH
-- =====================================================================

create or replace function public.discard_import(
  p_batch_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_total integer;
begin
  v_branch_id := public._inventory_branch();

  perform 1
  from public.inventory_import_batches b
  where b.id = p_batch_id
    and b.branch_id = v_branch_id
    and b.status = 'reviewing'
  for update;

  if not found then
    raise exception 'Import batch not found or has already been processed';
  end if;

  select count(*)::integer
    into v_total
  from public.inventory_import_rows r
  where r.batch_id = p_batch_id;

  -- Remove staged rows but retain the batch record for history.
  delete from public.inventory_import_rows
  where batch_id = p_batch_id;

  update public.inventory_import_batches
  set
    status = 'discarded',
    discarded_at = now(),
    updated_at = now(),
    total_rows = v_total,
    valid_rows = 0,
    error_rows = 0
  where id = p_batch_id;

  return jsonb_build_object(
    'discarded', true,
    'batch_id', p_batch_id,
    'discarded_rows', v_total
  );
end;
$$;


-- =====================================================================
-- 5. PERMISSIONS
-- =====================================================================

revoke all on function public.update_inventory_import_row(
  uuid, text, integer, numeric, integer, date
) from public, anon;

revoke all on function public.remove_inventory_import_row(uuid)
  from public, anon;

revoke all on function public.publish_import(uuid)
  from public, anon;

revoke all on function public.discard_import(uuid)
  from public, anon;

grant execute on function public.update_inventory_import_row(
  uuid, text, integer, numeric, integer, date
) to authenticated;

grant execute on function public.remove_inventory_import_row(uuid)
  to authenticated;

grant execute on function public.publish_import(uuid)
  to authenticated;

grant execute on function public.discard_import(uuid)
  to authenticated;

commit;
