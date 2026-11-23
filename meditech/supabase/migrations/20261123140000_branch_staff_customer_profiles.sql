-- Pharmacy staff may read customer profile fields for patients with reservations at their branch.
create policy "Branch staff see reservation customer profiles"
  on public.customer_profiles
  for select to authenticated
  using (
    exists (
      select 1
      from public.reservations r
      where r.customer_id = customer_profiles.account_id
        and r.branch_id = public.my_branch_id()
    )
  );

create policy "Branch staff see reservation customer accounts"
  on public.accounts
  for select to authenticated
  using (
    exists (
      select 1
      from public.reservations r
      where r.customer_id = accounts.id
        and r.branch_id = public.my_branch_id()
    )
  );