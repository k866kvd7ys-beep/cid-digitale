begin;

create or replace function public.insurance_case_file_audit_write()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_claim_id text;
  v_record_id uuid;
  v_changed jsonb := '{}'::jsonb;
  v_actor_user_id uuid;
  v_entity_type text;
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new);
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
  elsif tg_op = 'DELETE' then
    v_old := to_jsonb(old);
  else
    raise exception 'unsupported_insurance_case_file_audit_operation:%', tg_op;
  end if;

  if tg_table_name = 'insurance_case_file_records' then
    v_entity_type := 'record';

    if tg_op = 'DELETE' then
      v_claim_id := old.claim_id;
      v_record_id := old.id;
      v_actor_user_id := coalesce(auth.uid(), old.updated_by);
    else
      v_claim_id := new.claim_id;
      v_record_id := new.id;
      v_actor_user_id := coalesce(auth.uid(), new.updated_by);
    end if;
  elsif tg_table_name = 'insurance_case_file_attachments' then
    v_entity_type := 'attachment';

    if tg_op = 'DELETE' then
      v_claim_id := old.claim_id;
      v_record_id := old.record_id;
      v_actor_user_id := coalesce(auth.uid(), old.created_by);
    else
      v_claim_id := new.claim_id;
      v_record_id := new.record_id;
      v_actor_user_id := coalesce(auth.uid(), new.created_by);
    end if;
  else
    raise exception
      'unsupported_insurance_case_file_audit_table:%',
      tg_table_name;
  end if;

  if tg_op = 'UPDATE' then
    select coalesce(jsonb_object_agg(n.key, n.value), '{}'::jsonb)
      into v_changed
    from jsonb_each(v_new) n
    where (v_old -> n.key) is distinct from n.value;
  elsif tg_op = 'INSERT' then
    v_changed := coalesce(v_new, '{}'::jsonb);
  else
    v_changed := coalesce(v_old, '{}'::jsonb);
  end if;

  insert into public.insurance_case_file_audit (
    claim_id,
    record_id,
    entity_type,
    action,
    changed_fields,
    old_data,
    new_data,
    actor_user_id
  ) values (
    v_claim_id,
    v_record_id,
    v_entity_type,
    lower(tg_op),
    v_changed,
    v_old,
    v_new,
    v_actor_user_id
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

comment on function public.insurance_case_file_audit_write()
is 'Audits insurance dossier records by records.id and attachments by attachments.record_id without resolving fields that do not exist on the triggering row type.';

commit;
