begin;

create or replace function public.submit_public_insurance_information_request(
  p_token text,
  p_confirm_truth boolean,
  p_confirm_privacy boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_token_hash text;
  v_request public.insurance_information_requests;
  v_record public.insurance_case_file_records;
  v_emergency public.insurance_case_file_records;
  v_item public.insurance_information_request_items;
  v_value jsonb;
  v_text text;
  v_actor_user_id uuid;
  v_submitted_at timestamptz;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    raise exception 'information_request_invalid';
  end if;

  if not coalesce(p_confirm_truth, false)
      or not coalesce(p_confirm_privacy, false) then
    raise exception 'information_request_confirmations_required';
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

  if v_request.record_type not in ('witness', 'injured') then
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

  select *
  into v_record
  from public.insurance_case_file_records
  where id = v_request.record_id
    and claim_id = v_request.claim_id
    and record_type = v_request.record_type
    and source_index = v_request.source_index;

  if not found then
    raise exception 'information_request_record_not_found';
  end if;

  for v_item in
    select *
    from public.insurance_information_request_items
    where request_id = v_request.id
      and required
      and field_key <> 'digital_signature_text'
    order by sort_order
  loop
    if v_item.field_type = 'document' then
      if v_item.field_key = 'digital_signature'
          and not exists (
            select 1
            from public.insurance_information_request_attachments a
            join storage.objects o
              on o.bucket_id = a.bucket
              and o.name = a.object_path
            where a.request_id = v_request.id
              and a.field_key = v_item.field_key
              and a.upload_status = 'uploaded'
          ) then
        raise exception 'required_document_missing:%', v_item.field_key;
      end if;
    else
      v_value := public.insurance_information_request_effective_value(
        v_request.id,
        v_item.field_key
      );
      if v_value is null
          or v_value = 'null'::jsonb
          or v_value = '""'::jsonb then
        raise exception 'required_information_missing:%', v_item.field_key;
      end if;
    end if;
  end loop;

  select *
  into v_emergency
  from public.insurance_case_file_records
  where claim_id = v_request.claim_id
    and record_type = 'emergency_contact'
    and source_index = 0;

  for v_item in
    select *
    from public.insurance_information_request_items
    where request_id = v_request.id
      and field_type <> 'document'
      and field_key <> 'digital_signature_text'
  loop
    v_value := public.insurance_information_request_effective_value(
      v_request.id,
      v_item.field_key
    );
    v_text := nullif(btrim(v_value #>> '{}'), '');

    case v_item.field_key
      when 'first_name' then v_record.first_name := v_text;
      when 'last_name' then v_record.last_name := v_text;
      when 'birth_date' then v_record.birth_date := v_text::date;
      when 'gender' then v_record.gender := v_text;
      when 'nationality' then v_record.nationality := v_text;
      when 'spoken_language' then v_record.spoken_language := v_text;
      when 'phone' then v_record.phone := v_text;
      when 'email' then v_record.email := v_text;
      when 'street' then v_record.street := v_text;
      when 'postal_code' then v_record.postal_code := v_text;
      when 'city' then v_record.city := v_text;
      when 'country' then v_record.country := v_text;
      when 'document_type' then v_record.document_type := v_text;
      when 'document_number' then v_record.document_number := v_text;
      when 'document_expiry' then v_record.document_expiry := v_text::date;
      when 'witness_statement' then v_record.witness_statement := v_text;
      when 'injury_severity' then v_record.injury_severity := v_text;
      when 'body_part' then v_record.body_part := v_text;
      when 'ambulance_attended' then
        v_record.ambulance_attended := v_text::boolean;
      when 'hospitalized' then v_record.hospitalized := v_text::boolean;
      when 'hospital_name' then v_record.hospital_name := v_text;
      when 'doctor_name' then v_record.doctor_name := v_text;
      when 'hospital_case_number' then
        v_record.hospital_case_number := v_text;
      when 'medical_notes' then v_record.notes := v_text;
      when 'emergency_first_name' then v_emergency.first_name := v_text;
      when 'emergency_last_name' then v_emergency.last_name := v_text;
      when 'emergency_relationship' then v_emergency.relationship := v_text;
      when 'emergency_phone' then v_emergency.phone := v_text;
      when 'emergency_email' then v_emergency.email := v_text;
      else v_text := v_text;
    end case;
  end loop;

  v_actor_user_id := v_request.insurance_user_id;
  perform set_config(
    'request.jwt.claim.sub',
    v_actor_user_id::text,
    true
  );
  perform set_config(
    'app.insurance_information_request_id',
    v_request.id::text,
    true
  );

  if v_request.status = 'draft' then
    update public.insurance_information_requests
    set status = 'opened',
        updated_at = now()
    where id = v_request.id;
  end if;

  update public.insurance_case_file_records
  set first_name = v_record.first_name,
      last_name = v_record.last_name,
      birth_date = v_record.birth_date,
      gender = v_record.gender,
      nationality = v_record.nationality,
      spoken_language = v_record.spoken_language,
      phone = v_record.phone,
      email = v_record.email,
      street = v_record.street,
      postal_code = v_record.postal_code,
      city = v_record.city,
      country = v_record.country,
      document_type = v_record.document_type,
      document_number = v_record.document_number,
      document_expiry = v_record.document_expiry,
      witness_statement = v_record.witness_statement,
      digital_signature_text = v_record.digital_signature_text,
      injury_severity = v_record.injury_severity,
      body_part = v_record.body_part,
      ambulance_attended = v_record.ambulance_attended,
      hospitalized = v_record.hospitalized,
      hospital_name = v_record.hospital_name,
      doctor_name = v_record.doctor_name,
      hospital_case_number = v_record.hospital_case_number,
      notes = v_record.notes
  where id = v_record.id;

  if v_request.record_type = 'injured' and exists (
    select 1
    from public.insurance_information_request_items
    where request_id = v_request.id
      and category = 'emergency'
  ) then
    insert into public.insurance_case_file_records as r (
      id,
      claim_id,
      record_type,
      source_index,
      first_name,
      last_name,
      relationship,
      phone,
      email
    ) values (
      coalesce(v_emergency.id, extensions.gen_random_uuid()),
      v_request.claim_id,
      'emergency_contact',
      0,
      v_emergency.first_name,
      v_emergency.last_name,
      v_emergency.relationship,
      v_emergency.phone,
      v_emergency.email
    )
    on conflict (claim_id, record_type, source_index) do update
    set first_name = excluded.first_name,
        last_name = excluded.last_name,
        relationship = excluded.relationship,
        phone = excluded.phone,
        email = excluded.email;
  end if;

  insert into public.insurance_case_file_attachments (
    claim_id,
    record_id,
    category,
    bucket,
    object_path,
    file_name,
    mime_type,
    byte_size,
    created_by
  )
  select v_request.claim_id,
         v_request.record_id,
         a.category,
         a.bucket,
         a.object_path,
         a.file_name,
         a.mime_type,
         a.byte_size,
         v_actor_user_id
  from public.insurance_information_request_attachments a
  where a.request_id = v_request.id
    and a.upload_status = 'uploaded'
  on conflict (object_path) do nothing;

  update public.insurance_information_request_attachments
  set upload_status = 'transferred'
  where request_id = v_request.id
    and upload_status = 'uploaded';

  v_submitted_at := now();
  update public.insurance_information_requests
  set status = 'submitted',
      submitted_at = v_submitted_at,
      updated_at = v_submitted_at
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
    'information_request_submitted',
    'recipient_token',
    null,
    jsonb_build_object(
      'item_count',
      (
        select count(*)
        from public.insurance_information_request_items
        where request_id = v_request.id
      ),
      'attachment_count',
      (
        select count(*)
        from public.insurance_information_request_attachments
        where request_id = v_request.id
      ),
      'truth_confirmed',
      true,
      'privacy_confirmed',
      true
    )
  );

  return jsonb_build_object(
    'submitted',
    true,
    'submitted_at',
    v_submitted_at
  );
end;
$$;

revoke all on function public.submit_public_insurance_information_request(
  text,
  boolean,
  boolean
) from public;

grant execute on function public.submit_public_insurance_information_request(
  text,
  boolean,
  boolean
) to anon, authenticated;

commit;
