begin;

alter table public.insurance_case_file_audit
  drop constraint if exists insurance_case_file_audit_action_check;

alter table public.insurance_case_file_audit
  add constraint insurance_case_file_audit_action_check
  check (action in ('insert', 'update', 'delete', 'attachment_deleted'));

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
  v_action text;
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
    v_action := lower(tg_op);

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
    v_action := case
      when tg_op = 'DELETE' then 'attachment_deleted'
      else lower(tg_op)
    end;

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
    v_action,
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

create or replace function public.prepare_insurance_case_file_attachment_delete(
  p_claim_id text,
  p_attachment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_attachment public.insurance_case_file_attachments;
begin
  if not public.is_claim_insurance_editor(p_claim_id) then
    raise exception 'insurance_claim_participant_required_for_case_file';
  end if;

  select a.*
    into v_attachment
  from public.insurance_case_file_attachments a
  where a.id = p_attachment_id
    and a.claim_id = p_claim_id;

  if not found then
    raise exception 'insurance_case_file_attachment_not_found';
  end if;

  return to_jsonb(v_attachment);
end;
$$;

create or replace function public.delete_insurance_case_file_attachment(
  p_claim_id text,
  p_attachment_id uuid,
  p_object_path text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_attachment public.insurance_case_file_attachments;
begin
  if not public.is_claim_insurance_editor(p_claim_id) then
    raise exception 'insurance_claim_participant_required_for_case_file';
  end if;

  select a.*
    into v_attachment
  from public.insurance_case_file_attachments a
  where a.id = p_attachment_id
    and a.claim_id = p_claim_id
    and a.object_path = p_object_path
  for update;

  if not found then
    raise exception 'insurance_case_file_attachment_not_found_or_changed';
  end if;

  delete from public.insurance_case_file_attachments a
  where a.id = v_attachment.id
    and a.claim_id = p_claim_id
    and a.object_path = p_object_path;

  return to_jsonb(v_attachment);
end;
$$;

revoke all on function public.prepare_insurance_case_file_attachment_delete(
  text, uuid
) from public;
revoke all on function public.delete_insurance_case_file_attachment(
  text, uuid, text
) from public;

grant execute on function public.prepare_insurance_case_file_attachment_delete(
  text, uuid
) to authenticated;
grant execute on function public.delete_insurance_case_file_attachment(
  text, uuid, text
) to authenticated;

comment on function public.prepare_insurance_case_file_attachment_delete(text, uuid)
is 'Authorizes an assigned insurance editor and returns the authoritative private Storage path before deletion.';
comment on function public.delete_insurance_case_file_attachment(text, uuid, text)
is 'Deletes exactly one authorized insurance dossier attachment metadata row after its private Storage object has been removed.';

commit;
