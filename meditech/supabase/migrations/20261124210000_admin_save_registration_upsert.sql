-- Link catalogue rows to an existing CPR when the number is already in drug_registrations
-- (retries, second pack size, or seeded medicines gaining a registration).

create or replace function public.admin_save_registration(p jsonb)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  reg_id uuid := (p->>'id')::uuid;
  reg_num text := trim(p->>'registration_number');
begin
  if not public.is_admin() then
    raise exception 'NOT_ALLOWED';
  end if;

  if reg_id is null and reg_num <> '' then
    select id into reg_id
    from public.drug_registrations
    where registration_number = reg_num;
  end if;

  if reg_id is null then
    insert into public.drug_registrations
      (registration_number, generic_name, brand_name, strength, dosage_form_id, manufacturer, is_rx)
    values
      (reg_num, trim(p->>'generic_name'), nullif(trim(p->>'brand_name'), ''),
       trim(p->>'strength'), (p->>'dosage_form_id')::smallint, nullif(trim(p->>'manufacturer'), ''),
       coalesce((p->>'is_rx')::boolean, false))
    returning id into reg_id;
  else
    update public.drug_registrations set
      registration_number = reg_num,
      generic_name = trim(p->>'generic_name'),
      brand_name = nullif(trim(p->>'brand_name'), ''),
      strength = trim(p->>'strength'),
      dosage_form_id = (p->>'dosage_form_id')::smallint,
      manufacturer = nullif(trim(p->>'manufacturer'), ''),
      is_rx = coalesce((p->>'is_rx')::boolean, false)
    where id = reg_id;
  end if;

  perform public.log_audit(auth.uid(), public.my_admin_name(), 'admin', 'admin_action',
    'Saved drug registration', reg_num);
  return reg_id;
end
$$;