begin;

create or replace function public.get_public_insurance_information_request(
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.insurance_information_requests;
  v_items jsonb;
  v_attachments jsonb;
  v_company text;
begin
  select * into v_request
  from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token)
  for update;

  if not found then
    return jsonb_build_object('state', 'invalid');
  end if;
  if v_request.status = 'submitted' then
    return jsonb_build_object('state', 'submitted');
  end if;
  if v_request.status = 'cancelled' then
    return jsonb_build_object('state', 'cancelled');
  end if;
  if v_request.status = 'expired' or v_request.expires_at <= now() then
    if v_request.status <> 'expired' then
      update public.insurance_information_requests
      set status = 'expired', updated_at = now()
      where id = v_request.id;

      insert into public.insurance_information_request_audit (
        request_id, claim_id, record_id, event_type, actor_kind
      ) values (
        v_request.id, v_request.claim_id, v_request.record_id,
        'information_request_expired', 'system'
      );
    end if;
    return jsonb_build_object('state', 'expired');
  end if;

  update public.insurance_information_requests
  set status = 'opened',
      first_opened_at = coalesce(first_opened_at, now()),
      last_opened_at = now(),
      updated_at = now()
  where id = v_request.id;

  if v_request.first_opened_at is null then
    insert into public.insurance_information_request_audit (
      request_id, claim_id, record_id, event_type, actor_kind, actor_user_id
    ) values (
      v_request.id, v_request.claim_id, v_request.record_id,
      'information_request_opened', 'recipient_token', null
    );
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'field_key', i.field_key,
      'field_type', i.field_type,
      'category', i.category,
      'required', i.required,
      'requested_document_category', i.requested_document_category,
      'value', public.insurance_information_request_effective_value(
        i.request_id, i.field_key
      )
    ) order by i.sort_order
  ), '[]'::jsonb)
  into v_items
  from public.insurance_information_request_items i
  where i.request_id = v_request.id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'field_key', a.field_key,
    'category', a.category,
    'file_name', a.file_name,
    'mime_type', a.mime_type,
    'byte_size', a.byte_size,
    'created_at', a.created_at
  ) order by a.created_at), '[]'::jsonb)
  into v_attachments
  from public.insurance_information_request_attachments a
  where a.request_id = v_request.id
    and a.upload_status = 'uploaded';

  select coalesce(
    nullif(btrim(p.company_name), ''),
    nullif(btrim(p.display_name), ''),
    'Insurance'
  )
  into v_company
  from public.profiles p
  where p.id = v_request.insurance_user_id;

  return jsonb_build_object(
    'state', 'active',
    'record_type', v_request.record_type,
    'company_name', coalesce(v_company, 'Insurance'),
    'claim_reference', upper(left(v_request.claim_id, 8)),
    'expires_at', v_request.expires_at,
    'message', v_request.insurance_message,
    'locale', v_request.locale,
    'items', v_items,
    'attachments', v_attachments
  );
end;
$$;

revoke all on function public.get_public_insurance_information_request(text)
from public;

grant execute on function public.get_public_insurance_information_request(text)
to anon, authenticated;

commit;
