-- Allow guests and signed-in customers to read approved branch storefront rows in branch_documents
-- so storage.objects policy "Customers read approved storefront photos" succeeds for all storefront uploads.
drop policy if exists "Customers see approved storefront documents" on public.branch_documents;
create policy "Customers see approved storefront documents" on public.branch_documents
  for select to anon, authenticated
  using (
    kind = 'storefront'
    and mime_type like 'image/%'
    and exists (
      select 1 from public.public_branches b where b.id = branch_id
    )
  );
