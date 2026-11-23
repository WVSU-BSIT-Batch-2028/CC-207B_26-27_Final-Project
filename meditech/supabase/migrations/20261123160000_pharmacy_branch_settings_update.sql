-- Branch owner may update public contact fields for their branch.
create policy "Owner updates own branch profile"
  on public.branches
  for update to authenticated
  using (
    id = public.my_branch_id()
    and public.my_staff_role() = 'owner'
  )
  with check (
    id = public.my_branch_id()
    and public.my_staff_role() = 'owner'
  );

-- Staff may update their own PRC fields on their staff record.
create policy "Staff updates own PRC"
  on public.staff_members
  for update to authenticated
  using (account_id = auth.uid())
  with check (account_id = auth.uid());