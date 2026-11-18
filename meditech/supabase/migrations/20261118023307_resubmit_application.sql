-- When an application was last resubmitted
alter table public.branches add column resubmitted_at timestamptz;

-- A rejected owner may upload new files into their own branch folder
create policy "Owner uploads documents while rejected" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'pharmacy-documents'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
    and public.my_staff_role() = 'owner'
    and exists (select 1 from public.branches b
                where b.id = public.my_branch_id() and b.status = 'rejected')
  );

-- The owner's own application, for filling in the edit form
create or replace function public.my_application_for_edit()
returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'display_id', b.display_id,
    'status', b.status,
    'rejection_reason', b.rejection_reason,
    'pharmacy_name', b.pharmacy_name,
    'branch_name', b.branch_name,
    'address', b.address,
    'contact_number', b.contact_number,
    'pharmacy_email', b.email,
    'latitude', b.latitude,
    'longitude', b.longitude,
    'lto_number', b.lto_number,
    'lto_expiry', b.lto_expiry,
    'hours', coalesce((
      select jsonb_agg(jsonb_build_object(
               'weekday', h.weekday, 'opens_at', h.opens_at,
               'closes_at', h.closes_at, 'is_closed', h.is_closed)
             order by h.weekday)
      from public.branch_hours h where h.branch_id = b.id), '[]'::jsonb),
    'first_name', o.first_name,
    'middle_name', o.middle_name,
    'last_name', o.last_name,
    'mobile', o.mobile
  )
  from public.branches b
  join public.staff_members o
    on o.branch_id = b.id and o.account_id = auth.uid() and o.role = 'owner'
$$;

-- Save the edited application and put it back in the review queue
create or replace function public.resubmit_pharmacy_application(p jsonb)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  my_branch uuid := public.my_branch_id();
  b public.branches%rowtype;
  owner_name text := (p->>'first_name') || ' ' || (p->>'last_name');
  doc jsonb;
begin
  -- Only the owner of a rejected application can resubmit
  if my_branch is null or public.my_staff_role() is distinct from 'owner' then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into b from public.branches where id = my_branch for update;
  if b.status <> 'rejected' then
    raise exception 'NOT_REJECTED';
  end if;
  if (p->>'lto_expiry')::date < public.app_today() then
    raise exception 'LTO_EXPIRED';
  end if;

  -- Updated details; same PHM number and original submitted date
  update public.branches set
    pharmacy_name = p->>'pharmacy_name',
    branch_name = p->>'branch_name',
    address = p->>'address',
    contact_number = p->>'contact_number',
    email = p->>'pharmacy_email',
    latitude = (p->>'latitude')::numeric,
    longitude = (p->>'longitude')::numeric,
    lto_number = p->>'lto_number',
    lto_expiry = (p->>'lto_expiry')::date,
    status = 'pending_approval',
    rejection_reason = null,
    resubmitted_at = now()
  where id = my_branch;

  -- Replace the opening hours
  delete from public.branch_hours where branch_id = my_branch;
  insert into public.branch_hours (branch_id, weekday, opens_at, closes_at, is_closed)
  select my_branch, (h->>'weekday')::smallint, (h->>'opens_at')::time,
         (h->>'closes_at')::time, coalesce((h->>'is_closed')::boolean, false)
  from jsonb_array_elements(p->'hours') as h;

  -- Updated owner name and mobile
  update public.staff_members set
    first_name = p->>'first_name',
    middle_name = nullif(p->>'middle_name', ''),
    last_name = p->>'last_name',
    mobile = p->>'mobile'
  where account_id = auth.uid();

  -- New files, if any were uploaded (must be in this branch's own folder)
  for doc in select * from jsonb_array_elements(coalesce(p->'documents', '[]'::jsonb)) loop
    if split_part(doc->>'path', '/', 1) <> my_branch::text then
      raise exception 'BAD_DOCUMENT_PATH';
    end if;
    insert into public.branch_documents (branch_id, kind, storage_path, mime_type, size_bytes, uploaded_by)
    values (my_branch, (doc->>'kind')::public.document_kind, doc->>'path',
            doc->>'mime_type', (doc->>'size_bytes')::int, auth.uid());
  end loop;

  -- The owner waits for review again
  update public.accounts set state = 'pending_approval' where id = auth.uid();

  perform public.log_audit(auth.uid(), owner_name, 'owner', 'pharmacy_application',
    'Resubmitted pharmacy application', b.display_id);
end
$$;

-- Signed-in owners may call these; each checks the caller itself
revoke execute on function public.my_application_for_edit() from public, anon;
revoke execute on function public.resubmit_pharmacy_application(jsonb) from public, anon;
grant execute on function public.my_application_for_edit() to authenticated;
grant execute on function public.resubmit_pharmacy_application(jsonb) to authenticated;