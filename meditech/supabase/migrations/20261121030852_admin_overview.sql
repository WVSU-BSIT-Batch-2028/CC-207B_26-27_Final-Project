-- Everything the admin overview shows, in one call
create or replace function public.admin_overview()
returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select case when not public.is_admin() then null else jsonb_build_object(
    -- Summary counts
    'pending_applications', (select count(*) from public.branches where status = 'pending_approval'),
    'active_pharmacies', (select count(*) from public.branches where status = 'active'),
    'inactive_pharmacies', (select count(*) from public.branches where status = 'inactive'),
    'medicines_pending_review', (select count(*) from public.medicines where status = 'draft'),
    'active_medicines', (select count(*) from public.medicines where status = 'active'),
    'open_requests', (select count(*) from public.medicine_requests where status = 'open'),
    'lto_expiring_soon', (select count(*) from public.branches
                          where status = 'active'
                            and lto_expiry <= public.app_today() + 60),

    -- The to-do list: what's waiting on the admin, oldest first (up to 12)
    'todo', coalesce((
      select jsonb_agg(item order by item->>'since')
      from (
        select item from (
          -- New pharmacy applications
          select jsonb_build_object(
                   'kind', 'application', 'id', b.id,
                   'title', b.pharmacy_name || ' · ' || b.branch_name,
                   'detail', 'New pharmacy application',
                   'since', b.submitted_at) as item
          from public.branches b where b.status = 'pending_approval'
          union all
          -- Open medicine requests
          select jsonb_build_object(
                   'kind', 'request', 'id', r.id,
                   'title', r.generic_name,
                   'detail', 'Requested by ' || b.pharmacy_name,
                   'since', r.created_at)
          from public.medicine_requests r
          join public.branches b on b.id = r.branch_id
          where r.status = 'open'
          union all
          -- Medicines waiting for an FDA check
          select jsonb_build_object(
                   'kind', 'medicine', 'id', m.id,
                   'title', m.brand_name || ' ' || m.strength,
                   'detail', 'Medicine waiting for an FDA check',
                   'since', m.created_at)
          from public.medicines m where m.status = 'draft'
          union all
          -- Licenses running out within 60 days
          select jsonb_build_object(
                   'kind', 'lto_expiring', 'id', b.id,
                   'title', b.pharmacy_name || ' · ' || b.branch_name,
                   'detail', 'LTO expires ' || to_char(b.lto_expiry, 'Mon DD, YYYY'),
                   'since', b.lto_expiry)
          from public.branches b
          where b.status = 'active' and b.lto_expiry <= public.app_today() + 60
        ) all_items
        order by item->>'since'
        limit 12
      ) first_items
    ), '[]'::jsonb)
  ) end
$$;

-- Signed-in users may call it; non-admins get nothing back
revoke execute on function public.admin_overview() from public, anon;
grant execute on function public.admin_overview() to authenticated;