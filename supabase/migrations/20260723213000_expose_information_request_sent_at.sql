begin;

create or replace function public.get_insurance_information_requests(
  p_claim_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
begin
  if not public.is_claim_insurance_editor(p_claim_id) then
    raise exception 'insurance_claim_participant_required_for_information_request';
  end if;

  perform public.expire_insurance_information_requests(p_claim_id);

  select coalesce(
    jsonb_agg(to_jsonb(q) order by q.created_at desc),
    '[]'::jsonb
  )
  into v_result
  from (
    select
      r.id,
      r.claim_id,
      r.record_id,
      r.record_type,
      r.source_index,
      r.recipient_email,
      r.recipient_phone,
      r.status,
      r.insurance_message,
      r.locale,
      r.expires_at,
      r.first_opened_at,
      r.last_opened_at,
      r.submitted_at,
      r.cancelled_at,
      r.created_at,
      (
        select max(a.occurred_at)
        from public.insurance_information_request_audit a
        where a.request_id = r.id
          and a.event_type = 'information_request_sent'
      ) as sent_at,
      nullif(
        btrim(concat_ws(' ', f.first_name, f.last_name)),
        ''
      ) as recipient_name,
      (
        select count(*)
        from public.insurance_information_request_items i
        where i.request_id = r.id
      ) as item_count,
      (
        select count(*)
        from public.insurance_information_request_items i
        where i.request_id = r.id
          and (
            (
              i.field_type = 'document'
              and exists (
                select 1
                from public.insurance_information_request_attachments a
                where a.request_id = r.id
                  and a.field_key = i.field_key
                  and a.upload_status in ('uploaded', 'transferred')
              )
            )
            or (
              i.field_type <> 'document'
              and public.insurance_information_request_effective_value(
                r.id,
                i.field_key
              ) is distinct from 'null'::jsonb
              and public.insurance_information_request_effective_value(
                r.id,
                i.field_key
              ) <> '""'::jsonb
            )
          )
      ) as completed_item_count
    from public.insurance_information_requests r
    join public.insurance_case_file_records f
      on f.id = r.record_id
    where r.claim_id = p_claim_id
  ) q;

  return v_result;
end;
$$;

comment on function public.get_insurance_information_requests(text)
is 'Returns authorized insurance information requests, including the latest real delivery timestamp from the request audit.';

commit;
