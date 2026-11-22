begin;
select plan(8);

-- Seed test rows using service_role
set local role service_role;

insert into public.osm_listings (osm_id, name, address, latitude, longitude, last_edited_there, status)
values
  ('node/990001', 'Test Shown Botika', 'Lapuz, Iloilo City', 10.720200, 122.562100, 'Mar 2025', 'shown'),
  ('node/990002', 'Test Hidden Botika', 'Jaro, Iloilo City', 10.725000, 122.558000, 'Nov 2023', 'hidden');

-- Grab an existing admin account ID while still service_role
select coalesce(
  (select account_id::text from public.admins limit 1),
  gen_random_uuid()::text
) as admin_uid \gset

-- 1. Anonymous guest can read shown listings
set local role anon;
select is(
  (select count(*)::int from public.osm_listings where osm_id = 'node/990001'),
  1,
  'Guest can read shown OpenStreetMap listings'
);

-- 2. Anonymous guest cannot read hidden listings
select is(
  (select count(*)::int from public.osm_listings where osm_id = 'node/990002'),
  0,
  'Guest cannot read hidden OpenStreetMap listings'
);

-- 3. Nearby search finds listing within 100 meters
select is(
  (select count(*)::int from public.find_nearby_osm_listings(10.720250, 122.562120, 100) where osm_id = 'node/990001'),
  1,
  'Nearby lookup returns shown listing within 100 meters'
);

-- 4. Signed-in non-admin cannot hide a listing
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', gen_random_uuid(),
  'role', 'authenticated',
  'app_account_type', 'customer',
  'app_state', 'active'
)::text, true);

select throws_ok(
  $$select public.admin_hide_osm_listing((select id from public.osm_listings where osm_id = 'node/990001'), 'Wrong barangay')$$,
  'Only administrators can hide OpenStreetMap listings.'
);

-- Switch to admin session
select set_config('request.jwt.claims', json_build_object(
  'sub', :'admin_uid',
  'role', 'authenticated',
  'app_account_type', 'admin',
  'app_state', 'active'
)::text, true);

-- 5. Admin can read hidden listings
select is(
  (select count(*)::int from public.osm_listings where osm_id = 'node/990002'),
  1,
  'Admin can read hidden OpenStreetMap listings'
);

-- 6. Admin hide enforces minimum 5 character reason
select throws_ok(
  $$select public.admin_hide_osm_listing((select id from public.osm_listings where osm_id = 'node/990001'), 'bad')$$,
  'Reason must be between 5 and 200 characters.'
);

-- 7. Admin can hide a shown listing with a valid reason
select lives_ok(
  $$select public.admin_hide_osm_listing((select id from public.osm_listings where osm_id = 'node/990001'), 'Pin was in the wrong barangay.')$$,
  'Admin can hide a shown OpenStreetMap listing'
);

-- 8. Admin can restore a hidden listing
select lives_ok(
  $$select public.admin_show_osm_listing((select id from public.osm_listings where osm_id = 'node/990001'))$$,
  'Admin can restore a hidden OpenStreetMap listing'
);

select * from finish();
rollback;