begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

-- =====================================================================
-- TEST DATA SETUP
-- =====================================================================

-- Two branches: active branch 1 and another active branch 2
insert into public.branches
  (id, pharmacy_name, branch_name, address, contact_number, email,
   latitude, longitude, lto_number, lto_expiry, status, approved_at)
values
  ('e2000000-0000-0000-0000-000000000001', 'Emp Pharma', 'Branch 1',
   '10 Rizal St', '0330001001', 'emp1@pharmacy.com',
   10.7202, 122.5621, 'EMP-LTO-0001', '2028-12-31', 'active', now()),
  ('e2000000-0000-0000-0000-000000000002', 'Emp Pharma', 'Branch 2',
   '20 Lopez St', '0330001002', 'emp2@pharmacy.com',
   10.7275, 122.5577, 'EMP-LTO-0002', '2028-12-31', 'active', now());

-- Users: owner1, pharmacist1, staff1, owner2, customer1
insert into auth.users (id, email) values
  ('e3000000-0000-0000-0000-000000000001', 'emp.owner1@staff.test'),
  ('e3000000-0000-0000-0000-000000000002', 'emp.pharma1@staff.test'),
  ('e3000000-0000-0000-0000-000000000003', 'emp.staff1@staff.test'),
  ('e3000000-0000-0000-0000-000000000004', 'emp.owner2@staff.test'),
  ('e1000000-0000-0000-0000-000000000001', 'emp.cust1@test.com');

insert into public.accounts (id, account_type, username) values
  ('e3000000-0000-0000-0000-000000000001', 'staff', 'emp_owner1'),
  ('e3000000-0000-0000-0000-000000000002', 'staff', 'emp_pharma1'),
  ('e3000000-0000-0000-0000-000000000003', 'staff', 'emp_staff1'),
  ('e3000000-0000-0000-0000-000000000004', 'staff', 'emp_owner2'),
  ('e1000000-0000-0000-0000-000000000001', 'customer', null);

insert into public.customer_profiles
  (account_id, first_name, last_name, mobile, email, birthdate, consent_version)
values
  ('e1000000-0000-0000-0000-000000000001', 'Emp', 'Customer', '09992000001',
   'emp.cust1@test.com', '1995-01-01', 'v1');

insert into public.staff_members
  (account_id, branch_id, role, first_name, last_name,
   prc_license_no, prc_license_expiry, license_status)
values
  ('e3000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-000000000001',
   'owner', 'Emp', 'Owner', null, null, 'none'),
  ('e3000000-0000-0000-0000-000000000002', 'e2000000-0000-0000-0000-000000000001',
   'pharmacist', 'Emp', 'Pharma', '1234567', '2030-12-31', 'pending'),
  ('e3000000-0000-0000-0000-000000000003', 'e2000000-0000-0000-0000-000000000001',
   'staff', 'Emp', 'Staff', null, null, 'none'),
  ('e3000000-0000-0000-0000-000000000004', 'e2000000-0000-0000-0000-000000000002',
   'owner', 'Other', 'Owner', null, null, 'none');

create or replace function set_auth_user(p_user_id uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end
$$;

create or replace function reset_auth()
returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end
$$;

-- =====================================================================
-- 1. LIST BRANCH EMPLOYEES
-- =====================================================================
select has_function('public', 'list_branch_employees', 'list_branch_employees exists');
select has_function('public', 'change_employee_role', 'change_employee_role exists');
select has_function('public', 'update_employee_license', 'update_employee_license exists');

-- Regular staff and customers cannot list employees
select set_auth_user('e3000000-0000-0000-0000-000000000003');
select throws_ok(
  $$ select * from public.list_branch_employees() $$,
  null, 'Only the pharmacy owner can view the employee list',
  'regular staff cannot list employees');
select reset_auth();

select set_auth_user('e1000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select * from public.list_branch_employees() $$,
  null, 'Only the pharmacy owner can view the employee list',
  'customer cannot list employees');
select reset_auth();

-- Owner sees only their own branch employees, including usernames
select set_auth_user('e3000000-0000-0000-0000-000000000001');
select is(
  (select count(*)::int from public.list_branch_employees()),
  3, 'owner sees all 3 members of their branch');
select is(
  (select username from public.list_branch_employees()
   where account_id = 'e3000000-0000-0000-0000-000000000003'),
  'emp_staff1', 'employee username is returned to the owner');
select reset_auth();

-- =====================================================================
-- 2. CHANGE EMPLOYEE ROLE
-- =====================================================================

-- Non-owner cannot change roles
select set_auth_user('e3000000-0000-0000-0000-000000000002');
select throws_ok(
  $$ select public.change_employee_role(
       'e3000000-0000-0000-0000-000000000003', 'pharmacist', '7654321', '2030-12-31') $$,
  null, 'Only the pharmacy owner can change employee roles',
  'pharmacist cannot change roles');
select reset_auth();

-- Owner cannot touch another branch's staff or themselves
select set_auth_user('e3000000-0000-0000-0000-000000000004');
select throws_ok(
  $$ select public.change_employee_role(
       'e3000000-0000-0000-0000-000000000003', 'pharmacist', '7654321', '2030-12-31') $$,
  null, 'Employee not found',
  'owner cannot change an employee from another branch');
select reset_auth();

select set_auth_user('e3000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.change_employee_role(
       'e3000000-0000-0000-0000-000000000001', 'staff') $$,
  null, 'You cannot change your own role',
  'owner cannot change their own role');

-- Promoting staff to pharmacist needs a valid 7-digit PRC and future expiry
select throws_ok(
  $$ select public.change_employee_role(
       'e3000000-0000-0000-0000-000000000003', 'pharmacist', '123', '2030-12-31') $$,
  null, 'PRC license number must be exactly 7 digits',
  'promoting to pharmacist requires 7-digit PRC number');

select throws_ok(
  $$ select public.change_employee_role(
       'e3000000-0000-0000-0000-000000000003', 'pharmacist', '7654321', '2020-01-01') $$,
  null, 'PRC license expiry must be today or later',
  'promoting to pharmacist requires unexpired date');

-- Valid promotion
select lives_ok(
  $$ select public.change_employee_role(
       'e3000000-0000-0000-0000-000000000003', 'pharmacist', '7654321', '2030-12-31') $$,
  'owner promotes staff to pharmacist');
select reset_auth();

select is(
  (select role::text || ':' || license_status::text from public.staff_members
   where account_id = 'e3000000-0000-0000-0000-000000000003'),
  'pharmacist:pending', 'promoted pharmacist starts with pending license');

-- Demoting back to staff works and clears verified license
select set_auth_user('e3000000-0000-0000-0000-000000000001');
select lives_ok(
  $$ select public.change_employee_role(
       'e3000000-0000-0000-0000-000000000003', 'staff') $$,
  'owner changes pharmacist back to staff');
select reset_auth();

select is(
  (select role::text || ':' || license_status::text from public.staff_members
   where account_id = 'e3000000-0000-0000-0000-000000000003'),
  'staff:none', 'demoted staff has license_status none');

-- =====================================================================
-- 3. LICENSE STATUS & OWNER SELF-LICENSE CONFIRMATION
-- =====================================================================

-- Staff role cannot receive a license directly
select set_auth_user('e3000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.update_employee_license(
       'e3000000-0000-0000-0000-000000000003', '7654321', '2030-12-31', true, false) $$,
  null, 'Change the employee role to pharmacist before adding a license',
  'cannot attach license to regular staff');

-- Cannot verify an expired license
select throws_ok(
  $$ select public.update_employee_license(
       'e3000000-0000-0000-0000-000000000002', '1234567', '2020-01-01', true, false) $$,
  null, 'Cannot verify an expired PRC license',
  'cannot verify an expired license');

-- Verifying pharmacist license works and notifies them
select lives_ok(
  $$ select public.update_employee_license(
       'e3000000-0000-0000-0000-000000000002', '1234567', '2030-12-31', true, false) $$,
  'owner verifies pharmacist license');
select reset_auth();

select is(
  (select license_status from public.staff_members
   where account_id = 'e3000000-0000-0000-0000-000000000002'),
  'verified'::public.license_status, 'pharmacist license is now verified');

select is(
  (select count(*)::int from public.notifications
   where recipient_id = 'e3000000-0000-0000-0000-000000000002'
     and type = 'license_verified'),
  1, 'pharmacist is notified when verified');

-- Owner's own license requires confirmation flag
select set_auth_user('e3000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.update_employee_license(
       'e3000000-0000-0000-0000-000000000001', '5555555', '2030-12-31', true, false) $$,
  null, 'Confirm your own PRC license details before saving',
  'owner self-license refuses without confirmation step');

select lives_ok(
  $$ select public.update_employee_license(
       'e3000000-0000-0000-0000-000000000001', '5555555', '2030-12-31', true, true) $$,
  'owner self-license succeeds with confirmation');
select reset_auth();

select is(
  (select license_status from public.staff_members
   where account_id = 'e3000000-0000-0000-0000-000000000001'),
  'verified'::public.license_status, 'owner license is verified');

select ok(
  exists (
    select 1 from public.activity_log
    where branch_id = 'e2000000-0000-0000-0000-000000000001'
      and action = 'Verified employee license'
  ),
  'license verification is logged in activity_log');

select * from finish();
rollback;
