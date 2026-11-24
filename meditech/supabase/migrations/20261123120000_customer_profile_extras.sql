-- Avatar path, saved addresses, notification preferences, and customer self-service updates

alter table public.customer_profiles
  add column if not exists avatar_path text;

create table public.customer_saved_addresses (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  label text not null default 'Home'
    constraint address_label_len check (char_length(label) between 1 and 40),
  line1 text not null
    constraint address_line1_len check (char_length(line1) between 3 and 200),
  line2 text
    constraint address_line2_len check (line2 is null or char_length(line2) <= 200),
  city text
    constraint address_city_len check (city is null or char_length(city) <= 80),
  province text
    constraint address_province_len check (province is null or char_length(province) <= 80),
  postal_code text
    constraint address_postal_len check (postal_code is null or postal_code ~ '^[0-9]{4}$'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index customer_saved_addresses_account_idx
  on public.customer_saved_addresses (account_id);

create trigger customer_saved_addresses_updated_at
  before update on public.customer_saved_addresses
  for each row execute function public.set_updated_at();

create table public.customer_notification_preferences (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  push_enabled boolean not null default true,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create trigger customer_notification_preferences_updated_at
  before update on public.customer_notification_preferences
  for each row execute function public.set_updated_at();

alter table public.customer_saved_addresses enable row level security;
alter table public.customer_notification_preferences enable row level security;

create policy "Customers manage own profile" on public.customer_profiles
  for update to authenticated
  using (account_id = auth.uid() and public.my_account_type() = 'customer')
  with check (account_id = auth.uid() and public.my_account_type() = 'customer');

create policy "Customers manage own addresses" on public.customer_saved_addresses
  for all to authenticated
  using (account_id = auth.uid() and public.my_account_type() = 'customer')
  with check (account_id = auth.uid() and public.my_account_type() = 'customer');

create policy "Customers manage own notification prefs" on public.customer_notification_preferences
  for all to authenticated
  using (account_id = auth.uid() and public.my_account_type() = 'customer')
  with check (account_id = auth.uid() and public.my_account_type() = 'customer');

-- Default notification preferences for existing customers
insert into public.customer_notification_preferences (account_id)
select cp.account_id
from public.customer_profiles cp
on conflict (account_id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'customer-avatars',
  'customer-avatars',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "Customers upload own avatar" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_account_type() = 'customer'
  );

create policy "Customers update own avatar" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_account_type() = 'customer'
  )
  with check (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_account_type() = 'customer'
  );

create policy "Customers delete own avatar" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_account_type() = 'customer'
  );

create policy "Anyone reads customer avatars" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'customer-avatars');