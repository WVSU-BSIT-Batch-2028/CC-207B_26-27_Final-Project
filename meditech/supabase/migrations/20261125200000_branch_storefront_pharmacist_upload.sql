-- Branch owners and pharmacists may replace the customer-facing storefront photo.
drop policy if exists "Owner uploads branch storefront" on storage.objects;
create policy "Owner uploads branch storefront" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'pharmacy-documents'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
    and (storage.foldername(name))[2] = 'storefront'
    and public.my_staff_role() in ('owner', 'pharmacist')
  );

drop policy if exists "Owner updates branch storefront" on storage.objects;
create policy "Owner updates branch storefront" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'pharmacy-documents'
    and (storage.foldername(name))[1] = public.my_branch_id()::text
    and public.my_staff_role() in ('owner', 'pharmacist')
  );

create or replace function public.owner_update_storefront(
  p_path text,
  p_mime text,
  p_size int
)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  bid uuid;
begin
  if public.my_staff_role() not in ('owner', 'pharmacist') then
    raise exception 'NOT_ALLOWED';
  end if;
  bid := public.my_branch_id();
  if bid is null then
    raise exception 'NO_BRANCH';
  end if;
  if p_mime not in ('image/jpeg', 'image/png', 'image/webp') then
    raise exception 'BAD_MIME';
  end if;
  if p_size < 1 or p_size > 5242880 then
    raise exception 'BAD_SIZE';
  end if;

  insert into public.branch_documents (branch_id, kind, storage_path, mime_type, size_bytes, uploaded_by)
  values (bid, 'storefront', p_path, p_mime, p_size, auth.uid());
end
$$;