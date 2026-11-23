-- Users may dismiss (delete) their own in-app notifications.
create policy "Delete own notifications" on public.notifications
  for delete to authenticated
  using (recipient_id = auth.uid());

grant delete on table public.notifications to authenticated;