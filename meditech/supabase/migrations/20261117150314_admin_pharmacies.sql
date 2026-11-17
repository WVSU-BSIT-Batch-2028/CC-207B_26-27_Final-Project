-- Admin list of pharmacies and applications, newest waiting ones first
create or replace function public.admin_list_pharmacies(
  p_status public.branch_status default null,
  p_search text default null
)
returns table (
  id uuid,
  display_id text,
  pharmacy_name text,
  branch_name text,
  address text,
  owner_name text,
  lto_number text,
  lto_expiry date,
  status public.branch_status,
  submitted_at timestamptz,
  possible_duplicate boolean
)
language sql stable security definer
set search_path = ''
as $$
  select b.id, b.display_id, b.pharmacy_name, b.branch_name, b.address,
         o.first_name || ' ' || o.last_name,
         b.lto_number, b.lto_expiry, b.status, b.submitted_at, b.possible_duplicate
  from public.branches b
  left join public.staff_members o on o.branch_id = b.id and o.role = 'owner'
  where public.is_admin()
    -- Optional status filter (All, Pending, Active, and so on)
    and (p_status is null or b.status = p_status)
    -- Optional search by pharmacy, branch, owner, LTO, or PHM number
    and (coalesce(p_search, '') = ''
         or b.pharmacy_name ilike '%' || p_search || '%'
         or b.branch_name ilike '%' || p_search || '%'
         or b.lto_number ilike '%' || p_search || '%'
         or b.display_id ilike '%' || p_search || '%'
         or (o.first_name || ' ' || o.last_name) ilike '%' || p_search || '%')
  order by (b.status = 'pending_approval') desc, b.submitted_at desc
$$;

-- One application with everything the admin needs to review it
create or replace function public.admin_get_application(p_branch_id uuid)
returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', b.id,
    'display_id', b.display_id,
    'pharmacy_name', b.pharmacy_name,
    'branch_name', b.branch_name,
    'address', b.address,
    'contact_number', b.contact_number,
    'email', b.email,
    'latitude', b.latitude,
    'longitude', b.longitude,
    'lto_number', b.lto_number,
    'lto_expiry', b.lto_expiry,
    'status', b.status,
    'submitted_at', b.submitted_at,
    'approved_at', b.approved_at,
    'rejection_reason', b.rejection_reason,
    'possible_duplicate', b.possible_duplicate,

    -- Opening hours, Sunday to Saturday
    'hours', coalesce((
      select jsonb_agg(jsonb_build_object(
               'weekday', h.weekday, 'opens_at', h.opens_at,
               'closes_at', h.closes_at, 'is_closed', h.is_closed)
             order by h.weekday)
      from public.branch_hours h where h.branch_id = b.id), '[]'::jsonb),

    -- The owner's details
    'owner', (
      select jsonb_build_object(
               'display_id', o.display_id,
               'name', concat_ws(' ', o.first_name, o.middle_name, o.last_name),
               'mobile', o.mobile,
               'email', u.email,
               'username', a.username)
      from public.staff_members o
      join public.accounts a on a.id = o.account_id
      join auth.users u on u.id = o.account_id
      where o.branch_id = b.id and o.role = 'owner'),

    -- The uploaded files (opened through short-lived links in the app)
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object(
               'kind', d.kind, 'path', d.storage_path, 'mime_type', d.mime_type,
               'size_bytes', d.size_bytes, 'uploaded_at', d.uploaded_at)
             order by d.uploaded_at)
      from public.branch_documents d where d.branch_id = b.id), '[]'::jsonb)
  )
  from public.branches b
  where b.id = p_branch_id and public.is_admin()
$$;

-- Signed-in users may call these; non-admins just get nothing back
revoke execute on function public.admin_list_pharmacies(public.branch_status, text) from public, anon;
revoke execute on function public.admin_get_application(uuid) from public, anon;
grant execute on function public.admin_list_pharmacies(public.branch_status, text) to authenticated;
grant execute on function public.admin_get_application(uuid) to authenticated;