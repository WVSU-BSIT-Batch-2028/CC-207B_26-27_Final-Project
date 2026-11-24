-- Customers can read branch details for pharmacies they reserved with (list + details embed).
create policy "Customers see branches for own reservations"
  on public.branches
  for select to authenticated
  using (
    exists (
      select 1
      from public.reservations r
      where r.branch_id = branches.id
        and r.customer_id = auth.uid()
    )
  );

-- Live updates on customer Reservations tab and pharmacy Reservations list.
alter publication supabase_realtime add table public.reservations;