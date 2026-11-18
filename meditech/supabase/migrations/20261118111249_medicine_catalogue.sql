-- Official FDA drug registrations
create table public.drug_registrations (
  id uuid primary key default gen_random_uuid(),
  registration_number text not null unique,
  generic_name text not null,
  brand_name text,
  strength text not null,
  dosage_form_id smallint not null references public.dosage_forms(id),
  manufacturer text,
  is_rx boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger drug_registrations_updated_at before update on public.drug_registrations
  for each row execute function public.set_updated_at();
alter table public.drug_registrations enable row level security;
create policy "Admins see registrations" on public.drug_registrations
  for select to authenticated using (public.is_admin());

-- Each catalogue entry points to its registration
alter table public.medicines add column registration_id uuid references public.drug_registrations(id);

-- The same registration can't be listed twice in the same form (same unit and pack)
create unique index one_entry_per_presentation
  on public.medicines (registration_id, unit_sold_id, coalesce(pack_description, ''))
  where registration_id is not null;

-- The admin's name, for records
create or replace function public.my_admin_name()
returns text
language sql stable security definer
set search_path = ''
as $$
  select display_name from public.admins where account_id = auth.uid()
$$;

-- Add or edit a registration (no id = new)
create or replace function public.admin_save_registration(p jsonb)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  reg_id uuid := (p->>'id')::uuid;
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  if reg_id is null then
    insert into public.drug_registrations
      (registration_number, generic_name, brand_name, strength, dosage_form_id, manufacturer, is_rx)
    values
      (trim(p->>'registration_number'), trim(p->>'generic_name'), nullif(trim(p->>'brand_name'), ''),
       trim(p->>'strength'), (p->>'dosage_form_id')::smallint, nullif(trim(p->>'manufacturer'), ''),
       coalesce((p->>'is_rx')::boolean, false))
    returning id into reg_id;
  else
    update public.drug_registrations set
      registration_number = trim(p->>'registration_number'),
      generic_name = trim(p->>'generic_name'),
      brand_name = nullif(trim(p->>'brand_name'), ''),
      strength = trim(p->>'strength'),
      dosage_form_id = (p->>'dosage_form_id')::smallint,
      manufacturer = nullif(trim(p->>'manufacturer'), ''),
      is_rx = coalesce((p->>'is_rx')::boolean, false)
    where id = reg_id;
  end if;

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    'Saved drug registration', p->>'registration_number');
  return reg_id;
end
$$;

-- Add or edit a catalogue entry (no id = new; new entries start as draft)
create or replace function public.admin_save_medicine(p jsonb)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  med_id uuid := (p->>'id')::uuid;
  reg public.drug_registrations%rowtype;
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into reg from public.drug_registrations where id = (p->>'registration_id')::uuid;
  if not found then
    raise exception 'NEEDS_REGISTRATION';
  end if;

  if med_id is null then
    insert into public.medicines
      (registration_id, brand_name, generic_name, strength, dosage_form_id, unit_sold_id,
       pack_description, is_rx, status)
    values
      (reg.id, coalesce(nullif(trim(p->>'brand_name'), ''), reg.brand_name, reg.generic_name),
       reg.generic_name, reg.strength, reg.dosage_form_id, (p->>'unit_sold_id')::smallint,
       nullif(trim(p->>'pack_description'), ''), reg.is_rx, 'draft')
    returning id into med_id;
  else
    update public.medicines set
      registration_id = reg.id,
      brand_name = coalesce(nullif(trim(p->>'brand_name'), ''), reg.brand_name, reg.generic_name),
      generic_name = reg.generic_name,
      strength = reg.strength,
      dosage_form_id = reg.dosage_form_id,
      unit_sold_id = (p->>'unit_sold_id')::smallint,
      pack_description = nullif(trim(p->>'pack_description'), ''),
      is_rx = reg.is_rx
    where id = med_id;
  end if;

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    'Saved catalogue medicine', med_id::text);
  return med_id;
end
$$;

-- Record an FDA check on a drug registration's current details
create or replace function public.record_registration_verification(
  p_registration_id uuid,
  p_result public.verification_result,
  p_notes text default null
)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  reg public.drug_registrations%rowtype;
  new_id uuid;
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into reg from public.drug_registrations where id = p_registration_id;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  -- Save the check with a copy of the details that were compared
  insert into public.verification_checks
    (subject_type, subject_id, checked_number, checked_details, result, notes, checked_by, checked_by_label)
  values
    ('drug_registration', reg.id, reg.registration_number,
     jsonb_build_object('generic_name', reg.generic_name, 'strength', reg.strength,
                        'dosage_form_id', reg.dosage_form_id),
     p_result, nullif(trim(p_notes), ''), auth.uid(), public.my_admin_name())
  returning id into new_id;

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    'Recorded product FDA check: ' || p_result::text, reg.registration_number);
  return new_id;
end
$$;

-- Is the latest check "matched", and on the registration's current details?
create or replace function public.registration_has_current_match(p_registration_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.drug_registrations r
    join lateral (
      select * from public.verification_checks c
      where c.subject_type = 'drug_registration' and c.subject_id = r.id
      order by c.checked_at desc
      limit 1
    ) latest on true
    where r.id = p_registration_id
      and latest.result = 'matched'
      and latest.checked_number = r.registration_number
      and latest.checked_details ->> 'generic_name' = r.generic_name
      and latest.checked_details ->> 'strength' = r.strength
      and (latest.checked_details ->> 'dosage_form_id')::smallint = r.dosage_form_id
  )
$$;

-- Activate or deactivate a catalogue entry
create or replace function public.set_medicine_status(
  p_medicine_id uuid,
  p_status public.medicine_status,
  p_reason text default null
)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  med public.medicines%rowtype;
  reason text := trim(coalesce(p_reason, ''));
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into med from public.medicines where id = p_medicine_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  -- Going live needs a matched FDA check on its registration
  if p_status = 'active' then
    if med.registration_id is null or not public.registration_has_current_match(med.registration_id) then
      raise exception 'NEEDS_FDA_CHECK';
    end if;
    update public.medicines set status = 'active', deactivation_reason = null where id = med.id;

  -- Taking it down needs a reason
  elsif p_status = 'inactive' then
    if length(reason) not between 5 and 200 then
      raise exception 'REASON_LENGTH';
    end if;
    update public.medicines set status = 'inactive', deactivation_reason = reason where id = med.id;
  else
    raise exception 'BAD_STATUS';
  end if;

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    'Set medicine ' || p_status::text, med.display_id,
    case when reason <> '' then jsonb_build_object('reason', reason) else '{}'::jsonb end);
end
$$;

-- Admin catalogue list with search and status filter
create or replace function public.admin_list_medicines(
  p_status public.medicine_status default null,
  p_search text default null
)
returns table (
  id uuid,
  display_id text,
  brand_name text,
  generic_name text,
  strength text,
  dosage_form text,
  unit_sold text,
  pack_description text,
  is_rx boolean,
  status public.medicine_status,
  registration_id uuid,
  registration_number text,
  fda_matched boolean,
  pharmacies_stocking bigint
)
language sql stable security definer
set search_path = ''
as $$
  select m.id, m.display_id, m.brand_name, m.generic_name, m.strength,
         f.name, u.name, m.pack_description, m.is_rx, m.status,
         r.id, r.registration_number,
         coalesce(public.registration_has_current_match(r.id), false),
         (select count(*) from public.inventory_items i where i.medicine_id = m.id and i.is_active)
  from public.medicines m
  join public.dosage_forms f on f.id = m.dosage_form_id
  join public.units u on u.id = m.unit_sold_id
  left join public.drug_registrations r on r.id = m.registration_id
  where public.is_admin()
    and (p_status is null or m.status = p_status)
    and (coalesce(p_search, '') = ''
         or m.brand_name ilike '%' || p_search || '%'
         or m.generic_name ilike '%' || p_search || '%'
         or m.display_id ilike '%' || p_search || '%'
         or r.registration_number ilike '%' || p_search || '%')
  order by m.generic_name, m.brand_name, m.strength
$$;

-- Signed-in users may call these; each checks for an admin itself
revoke execute on function public.my_admin_name() from public, anon;
revoke execute on function public.admin_save_registration(jsonb) from public, anon;
revoke execute on function public.admin_save_medicine(jsonb) from public, anon;
revoke execute on function public.record_registration_verification(uuid, public.verification_result, text) from public, anon;
revoke execute on function public.registration_has_current_match(uuid) from public, anon;
revoke execute on function public.set_medicine_status(uuid, public.medicine_status, text) from public, anon;
revoke execute on function public.admin_list_medicines(public.medicine_status, text) from public, anon;
grant execute on function public.my_admin_name() to authenticated;
grant execute on function public.admin_save_registration(jsonb) to authenticated;
grant execute on function public.admin_save_medicine(jsonb) to authenticated;
grant execute on function public.record_registration_verification(uuid, public.verification_result, text) to authenticated;
grant execute on function public.registration_has_current_match(uuid) to authenticated;
grant execute on function public.set_medicine_status(uuid, public.medicine_status, text) to authenticated;
grant execute on function public.admin_list_medicines(public.medicine_status, text) to authenticated;