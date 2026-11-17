-- Employee management: list branch staff with usernames, change roles, and
-- manage PRC license status (including the owner's own license confirmation)

-- =====================================================================
-- 1. LIST BRANCH EMPLOYEES
-- Only the branch owner can list their team together with each username.
-- =====================================================================
create or replace function public.list_branch_employees()
returns table (
  account_id uuid,
  display_id text,
  username text,
  role public.staff_role,
  first_name text,
  middle_name text,
  last_name text,
  prc_license_no text,
  prc_license_expiry date,
  license_status public.license_status,
  is_active boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if public.my_account_type() <> 'staff' or public.my_staff_role() <> 'owner' then
    raise exception 'Only the pharmacy owner can view the employee list';
  end if;

  return query
  select sm.account_id,
         sm.display_id,
         a.username::text,
         sm.role,
         sm.first_name,
         sm.middle_name,
         sm.last_name,
         sm.prc_license_no,
         sm.prc_license_expiry,
         sm.license_status,
         sm.is_active
  from public.staff_members sm
  join public.accounts a on a.id = sm.account_id
  where sm.branch_id = public.my_branch_id()
  order by case sm.role when 'owner' then 0 when 'pharmacist' then 1 else 2 end,
           sm.created_at;
end
$$;

revoke execute on function public.list_branch_employees() from public, anon;
grant execute on function public.list_branch_employees() to authenticated;

-- =====================================================================
-- 2. CHANGE EMPLOYEE ROLE
-- A branch owner switches an employee between staff and pharmacist.
-- Promoting to pharmacist needs a 7-digit PRC number and unexpired date.
-- =====================================================================
create or replace function public.change_employee_role(
  p_employee_id uuid,
  p_new_role public.staff_role,
  p_prc_license_no text default null,
  p_prc_license_expiry date default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_branch_id uuid := public.my_branch_id();
  v_emp record;
  v_no text;
  v_expiry date;
  v_label text;
begin
  if public.my_account_type() <> 'staff' or public.my_staff_role() <> 'owner' then
    raise exception 'Only the pharmacy owner can change employee roles';
  end if;

  if not exists (
    select 1 from public.branches where id = v_branch_id and status = 'active'
  ) then
    raise exception 'Your pharmacy must be active to manage employees';
  end if;

  if p_employee_id = v_actor_id then
    raise exception 'You cannot change your own role';
  end if;

  if p_new_role = 'owner' then
    raise exception 'Cannot assign the owner role here';
  end if;

  select * into v_emp
  from public.staff_members
  where account_id = p_employee_id and branch_id = v_branch_id
  for update;

  if v_emp is null then
    raise exception 'Employee not found';
  end if;

  if v_emp.role = 'owner' then
    raise exception 'The owner role cannot be changed here';
  end if;

  if v_emp.role = p_new_role then
    return;
  end if;

  if p_new_role = 'pharmacist' then
    v_no := coalesce(nullif(trim(p_prc_license_no), ''), v_emp.prc_license_no);
    v_expiry := coalesce(p_prc_license_expiry, v_emp.prc_license_expiry);

    if v_no is null or v_no !~ '^[0-9]{7}$' then
      raise exception 'PRC license number must be exactly 7 digits';
    end if;

    if v_expiry is null or v_expiry < public.app_today() then
      raise exception 'PRC license expiry must be today or later';
    end if;

    update public.staff_members
    set role = 'pharmacist',
        prc_license_no = v_no,
        prc_license_expiry = v_expiry,
        license_status = 'pending',
        license_verified_by = null,
        license_verified_at = null
    where account_id = p_employee_id;
  else
    -- Demoting to regular staff clears any verified license privilege
    update public.staff_members
    set role = 'staff',
        license_status = 'none',
        license_verified_by = null,
        license_verified_at = null
    where account_id = p_employee_id;
  end if;

  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_branch_id, v_actor_id, coalesce(v_label, 'Owner'), 'owner',
    'Changed employee role', 'employee', v_emp.display_id,
    jsonb_build_object('from', v_emp.role::text, 'to', p_new_role::text)
  );
end
$$;

revoke execute on function public.change_employee_role(uuid, public.staff_role, text, date)
  from public, anon;
grant execute on function public.change_employee_role(uuid, public.staff_role, text, date)
  to authenticated;

-- =====================================================================
-- 3. UPDATE OR VERIFY PRC LICENSE
-- A branch owner updates a pharmacist's or their own PRC license.
-- Verified status requires an unexpired date; the owner's own license
-- requires an explicit confirmation flag.
-- =====================================================================
create or replace function public.update_employee_license(
  p_employee_id uuid,
  p_prc_license_no text,
  p_prc_license_expiry date,
  p_mark_verified boolean default false,
  p_owner_confirmed boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_branch_id uuid := public.my_branch_id();
  v_emp record;
  v_no text := trim(coalesce(p_prc_license_no, ''));
  v_status public.license_status;
  v_label text;
begin
  if public.my_account_type() <> 'staff' or public.my_staff_role() <> 'owner' then
    raise exception 'Only the pharmacy owner can update employee licenses';
  end if;

  if not exists (
    select 1 from public.branches where id = v_branch_id and status = 'active'
  ) then
    raise exception 'Your pharmacy must be active to manage employees';
  end if;

  select * into v_emp
  from public.staff_members
  where account_id = p_employee_id and branch_id = v_branch_id
  for update;

  if v_emp is null then
    raise exception 'Employee not found';
  end if;

  if v_emp.role = 'staff' then
    raise exception 'Change the employee role to pharmacist before adding a license';
  end if;

  if v_no !~ '^[0-9]{7}$' then
    raise exception 'PRC license number must be exactly 7 digits';
  end if;

  if p_prc_license_expiry is null then
    raise exception 'License expiry date is required';
  end if;

  -- Self-license updates/verifications by the owner require explicit confirmation
  if p_employee_id = v_actor_id and not p_owner_confirmed then
    raise exception 'Confirm your own PRC license details before saving';
  end if;

  if p_mark_verified then
    if p_prc_license_expiry < public.app_today() then
      raise exception 'Cannot verify an expired PRC license';
    end if;
    v_status := 'verified';
  elsif p_prc_license_expiry < public.app_today() then
    v_status := 'expired';
  else
    v_status := 'pending';
  end if;

  update public.staff_members
  set prc_license_no = v_no,
      prc_license_expiry = p_prc_license_expiry,
      license_status = v_status,
      license_verified_by = case when p_mark_verified then v_actor_id else null end,
      license_verified_at = case when p_mark_verified then now() else null end
  where account_id = p_employee_id;

  if p_mark_verified and p_employee_id <> v_actor_id then
    insert into public.notifications (recipient_id, type, title, body)
    values (p_employee_id, 'license_verified',
            'Your PRC license was verified',
            'You can now confirm and release reservations.');
  end if;

  v_label := public._staff_label(v_actor_id);
  perform public.log_activity(
    v_branch_id, v_actor_id, coalesce(v_label, 'Owner'), 'owner',
    case when p_mark_verified then 'Verified employee license' else 'Updated employee license' end,
    'employee', v_emp.display_id,
    jsonb_build_object('status', v_status::text, 'expires', p_prc_license_expiry)
  );
end
$$;

revoke execute on function public.update_employee_license(uuid, text, date, boolean, boolean)
  from public, anon;
grant execute on function public.update_employee_license(uuid, text, date, boolean, boolean)
  to authenticated;
