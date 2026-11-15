-- Let the app hear new notifications and read-receipts as they happen
alter publication supabase_realtime add table public.notifications;
alter table public.notifications replica identity full;