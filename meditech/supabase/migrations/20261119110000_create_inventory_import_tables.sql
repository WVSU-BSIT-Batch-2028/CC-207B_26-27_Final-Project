
-- Day 5: Inventory import staging tables
-- Uploaded data is stored here until the user publishes the import.
-- These tables do not modify live inventory.

begin;

create table public.inventory_import_batches (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  file_name text not null,
  file_type text not null
    check (file_type in ('csv', 'xlsx')),
  file_size_bytes integer not null
    check (file_size_bytes > 0 and file_size_bytes <= 2097152),
  status text not null default 'reviewing'
    check (status in ('reviewing', 'published', 'discarded')),
  total_rows integer not null default 0
    check (total_rows between 0 and 1000),
  valid_rows integer not null default 0
    check (valid_rows >= 0),
  error_rows integer not null default 0
    check (error_rows >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  discarded_at timestamptz,

  constraint inventory_import_batch_counts_check
    check (valid_rows + error_rows <= total_rows)
);

create table public.inventory_import_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null
    references public.inventory_import_batches(id) on delete cascade,
  source_row_number integer not null
    check (source_row_number > 0),

  -- Original uploaded row, retained for reference.
  raw_data jsonb not null default '{}'::jsonb,

  -- Parsed and editable review values.
  medicine_label text,
  stock_quantity integer,
  price_per_unit numeric(12, 2),
  low_stock_threshold integer,
  nearest_expiry date,

  -- Set when the medicine label matches the active catalogue.
  matched_medicine_id uuid references public.medicines(id),

  -- Validation feedback displayed in the review table.
  errors text[] not null default '{}',
  warnings text[] not null default '{}',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint inventory_import_rows_batch_row_unique
    unique (batch_id, source_row_number),

  constraint inventory_import_rows_stock_check
    check (stock_quantity is null or stock_quantity >= 0),

  constraint inventory_import_rows_price_check
    check (price_per_unit is null or price_per_unit > 0),

  constraint inventory_import_rows_threshold_check
    check (low_stock_threshold is null or low_stock_threshold >= 1)
);

create index inventory_import_batches_branch_created_idx
  on public.inventory_import_batches (branch_id, created_at desc);

create index inventory_import_rows_batch_row_idx
  on public.inventory_import_rows (batch_id, source_row_number);

create index inventory_import_rows_medicine_idx
  on public.inventory_import_rows (matched_medicine_id);

-- Enable row-level security.
alter table public.inventory_import_batches enable row level security;
alter table public.inventory_import_rows enable row level security;

-- Staff can read only import batches belonging to their own branch.
create policy "Branch staff can read their import batches"
  on public.inventory_import_batches
  for select
  to authenticated
  using (
    public.my_account_type() = 'staff'
    and branch_id = public.my_branch_id()
  );

-- Staff can read import rows only when the parent batch belongs to their branch.
create policy "Branch staff can read their import rows"
  on public.inventory_import_rows
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.inventory_import_batches b
      where b.id = inventory_import_rows.batch_id
        and b.branch_id = public.my_branch_id()
        and public.my_account_type() = 'staff'
    )
  );

-- The Edge Function and trusted database functions will perform writes.
-- Authenticated clients receive read-only access through the policies above.
grant select on public.inventory_import_batches to authenticated;
grant select on public.inventory_import_rows to authenticated;

commit;
