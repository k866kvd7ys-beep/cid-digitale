begin;

create or replace function public.save_public_insurance_information_request_draft(
  p_token text,
  p_values jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_token_hash text;
  v_request public.insurance_information_requests;
  v_item public.insurance_information_request_items;
  v_entry record;
  v_text text;
  v_max_length integer;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    raise exception 'information_request_invalid';
  end if;

  if p_values is null or jsonb_typeof(p_values) <> 'object' then
    raise exception 'invalid_draft_values';
  end if;

  v_token_hash := public.insurance_information_request_hash(p_token);

  select *
  into v_request
  from public.insurance_information_requests
  where token_hash = v_token_hash
  for update;

  if not found then
    raise exception 'information_request_invalid';
  end if;

  if v_request.record_type not in ('witness', 'injured') or not exists (
    select 1
    from public.insurance_case_file_records r
    where r.id = v_request.record_id
      and r.claim_id = v_request.claim_id
      and r.record_type = v_request.record_type
  ) then
    raise exception 'information_request_invalid';
  end if;

  if v_request.status = 'cancelled' then
    raise exception 'information_request_revoked';
  end if;

  if v_request.status = 'expired' or v_request.expires_at <= now() then
    raise exception 'information_request_expired';
  end if;

  if v_request.status = 'submitted' then
    raise exception 'information_request_completed';
  end if;

  if v_request.status not in ('draft', 'pending', 'opened') then
    raise exception 'information_request_not_editable';
  end if;

  for v_entry in select * from jsonb_each(p_values) loop
    select *
    into v_item
    from public.insurance_information_request_items
    where request_id = v_request.id
      and field_key = v_entry.key
      and field_type <> 'document';

    if not found then
      raise exception 'field_not_requested:%', v_entry.key;
    end if;

    v_text := nullif(btrim(v_entry.value #>> '{}'), '');
    v_max_length := 1000;
    if v_entry.key in (
      'witness_statement',
      'digital_signature_text',
      'medical_notes'
    ) then
      v_max_length := 10000;
    end if;

    if v_text is not null and length(v_text) > v_max_length then
      raise exception 'information_request_value_too_long:%', v_entry.key;
    end if;

    insert into public.insurance_information_request_values (
      request_id,
      field_key,
      value_text,
      value_boolean,
      value_date,
      updated_at
    ) values (
      v_request.id,
      v_entry.key,
      case when v_item.field_type = 'text' then v_text end,
      case
        when v_item.field_type in ('boolean', 'confirmation')
          and v_text is not null
        then v_text::boolean
      end,
      case
        when v_item.field_type = 'date' and v_text is not null
        then v_text::date
      end,
      now()
    )
    on conflict (request_id, field_key) do update
    set value_text = excluded.value_text,
        value_boolean = excluded.value_boolean,
        value_date = excluded.value_date,
        updated_at = now();
  end loop;

  update public.insurance_information_requests
  set status = 'draft',
      last_opened_at = now(),
      updated_at = now()
  where id = v_request.id;

  insert into public.insurance_information_request_audit (
    request_id,
    claim_id,
    record_id,
    event_type,
    actor_kind,
    actor_user_id,
    metadata
  ) values (
    v_request.id,
    v_request.claim_id,
    v_request.record_id,
    'information_request_draft_saved',
    'recipient_token',
    null,
    jsonb_build_object(
      'field_count',
      (select count(*) from jsonb_object_keys(p_values))
    )
  );

  return jsonb_build_object('saved', true, 'saved_at', now());
end;
$$;

revoke all on function public.save_public_insurance_information_request_draft(
  text,
  jsonb
) from public;

grant execute on function public.save_public_insurance_information_request_draft(
  text,
  jsonb
) to anon, authenticated;

commit;
