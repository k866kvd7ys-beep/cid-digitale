begin;

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.insurance_information_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  claim_id text not null references public.claims(id) on delete cascade,
  record_id uuid not null references public.insurance_case_file_records(id)
    on delete cascade,
  record_type text not null check (record_type in ('witness', 'injured')),
  source_index integer not null check (source_index >= 0),
  insurance_user_id uuid not null,
  recipient_email text,
  recipient_phone text,
  token_hash text not null unique,
  status text not null default 'pending' check (
    status in ('draft', 'pending', 'opened', 'submitted', 'expired', 'cancelled')
  ),
  insurance_message text,
  locale text not null default 'it' check (locale in ('it', 'de', 'fr', 'en')),
  expires_at timestamptz not null,
  first_opened_at timestamptz,
  last_opened_at timestamptz,
  submitted_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid()
);

create unique index if not exists insurance_information_requests_one_active_idx
on public.insurance_information_requests (record_id)
where status in ('draft', 'pending', 'opened');

create index if not exists insurance_information_requests_claim_idx
on public.insurance_information_requests (claim_id, created_at desc);

create index if not exists insurance_information_requests_token_idx
on public.insurance_information_requests (token_hash);

create table if not exists public.insurance_information_request_items (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null references public.insurance_information_requests(id)
    on delete cascade,
  field_key text not null,
  field_type text not null check (
    field_type in ('text', 'date', 'boolean', 'confirmation', 'document')
  ),
  category text not null,
  required boolean not null default true,
  requested_document_category text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (request_id, field_key),
  check (
    (field_type = 'document' and requested_document_category is not null)
    or (field_type <> 'document' and requested_document_category is null)
  )
);

create table if not exists public.insurance_information_request_values (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null,
  field_key text not null,
  value_text text,
  value_boolean boolean,
  value_date date,
  updated_at timestamptz not null default now(),
  unique (request_id, field_key),
  foreign key (request_id, field_key)
    references public.insurance_information_request_items(request_id, field_key)
    on delete cascade,
  check (num_nonnulls(value_text, value_boolean, value_date) <= 1)
);

create table if not exists public.insurance_information_request_attachments (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null references public.insurance_information_requests(id)
    on delete cascade,
  field_key text not null,
  category text not null,
  bucket text not null default 'insurance_case_files',
  object_path text not null unique,
  file_name text not null,
  mime_type text not null,
  byte_size bigint not null check (byte_size between 1 and 20971520),
  upload_status text not null default 'pending' check (
    upload_status in ('pending', 'uploaded', 'transferred')
  ),
  created_at timestamptz not null default now(),
  uploaded_at timestamptz,
  unique (request_id, id),
  foreign key (request_id, field_key)
    references public.insurance_information_request_items(request_id, field_key)
    on delete cascade
);

create index if not exists insurance_information_request_attachments_request_idx
on public.insurance_information_request_attachments (request_id, created_at);

create table if not exists public.insurance_information_request_audit (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.insurance_information_requests(id)
    on delete cascade,
  claim_id text not null references public.claims(id) on delete cascade,
  record_id uuid not null,
  event_type text not null check (event_type in (
    'information_request_created',
    'information_request_sent',
    'information_request_opened',
    'information_request_link_rotated',
    'information_request_draft_saved',
    'information_request_attachment_uploaded',
    'information_request_attachment_deleted',
    'information_request_submitted',
    'information_request_cancelled',
    'information_request_expired'
  )),
  actor_kind text not null check (actor_kind in ('insurance', 'recipient_token', 'system')),
  actor_user_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists insurance_information_request_audit_claim_idx
on public.insurance_information_request_audit (claim_id, occurred_at desc);

alter table public.insurance_case_file_records
  add column if not exists last_update_source text not null
    default 'insurance_manual' check (
      last_update_source in ('insurance_manual', 'secure_information_request')
    ),
  add column if not exists last_information_request_id uuid
    references public.insurance_information_requests(id) on delete set null;

alter table public.insurance_information_requests enable row level security;
alter table public.insurance_information_request_items enable row level security;
alter table public.insurance_information_request_values enable row level security;
alter table public.insurance_information_request_attachments enable row level security;
alter table public.insurance_information_request_audit enable row level security;

revoke all on public.insurance_information_requests from anon, authenticated;
revoke all on public.insurance_information_request_items from anon, authenticated;
revoke all on public.insurance_information_request_values from anon, authenticated;
revoke all on public.insurance_information_request_attachments from anon, authenticated;
revoke all on public.insurance_information_request_audit from anon, authenticated;

create or replace function public.insurance_information_request_hash(p_token text)
returns text
language sql
immutable
strict
set search_path = public, extensions
as $$
  select encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;

create or replace function public.insurance_information_request_field_definition(
  p_record_type text,
  p_field_key text
)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select case
    when p_record_type = 'witness' then case p_field_key
      when 'first_name' then jsonb_build_object('type','text','category','personal')
      when 'last_name' then jsonb_build_object('type','text','category','personal')
      when 'birth_date' then jsonb_build_object('type','date','category','personal')
      when 'nationality' then jsonb_build_object('type','text','category','personal')
      when 'spoken_language' then jsonb_build_object('type','text','category','personal')
      when 'phone' then jsonb_build_object('type','text','category','contacts')
      when 'email' then jsonb_build_object('type','text','category','contacts')
      when 'street' then jsonb_build_object('type','text','category','address')
      when 'postal_code' then jsonb_build_object('type','text','category','address')
      when 'city' then jsonb_build_object('type','text','category','address')
      when 'country' then jsonb_build_object('type','text','category','address')
      when 'document_type' then jsonb_build_object('type','text','category','document')
      when 'document_number' then jsonb_build_object('type','text','category','document')
      when 'document_expiry' then jsonb_build_object('type','date','category','document')
      when 'witness_statement' then jsonb_build_object('type','text','category','statement')
      when 'statement_confirmed' then jsonb_build_object('type','confirmation','category','statement')
      when 'digital_signature_text' then jsonb_build_object('type','text','category','statement')
      when 'document_photo' then jsonb_build_object('type','document','category','attachments','document_category','document_photo')
      when 'signed_statement' then jsonb_build_object('type','document','category','attachments','document_category','signed_statement')
      when 'digital_signature' then jsonb_build_object('type','document','category','attachments','document_category','digital_signature')
      when 'additional_document' then jsonb_build_object('type','document','category','attachments','document_category','additional_document')
    end
    when p_record_type = 'injured' then case p_field_key
      when 'first_name' then jsonb_build_object('type','text','category','personal')
      when 'last_name' then jsonb_build_object('type','text','category','personal')
      when 'birth_date' then jsonb_build_object('type','date','category','personal')
      when 'gender' then jsonb_build_object('type','text','category','personal')
      when 'nationality' then jsonb_build_object('type','text','category','personal')
      when 'phone' then jsonb_build_object('type','text','category','contacts')
      when 'email' then jsonb_build_object('type','text','category','contacts')
      when 'street' then jsonb_build_object('type','text','category','address')
      when 'postal_code' then jsonb_build_object('type','text','category','address')
      when 'city' then jsonb_build_object('type','text','category','address')
      when 'country' then jsonb_build_object('type','text','category','address')
      when 'injury_severity' then jsonb_build_object('type','text','category','medical')
      when 'body_part' then jsonb_build_object('type','text','category','medical')
      when 'ambulance_attended' then jsonb_build_object('type','boolean','category','medical')
      when 'hospitalized' then jsonb_build_object('type','boolean','category','medical')
      when 'hospital_name' then jsonb_build_object('type','text','category','medical')
      when 'doctor_name' then jsonb_build_object('type','text','category','medical')
      when 'hospital_case_number' then jsonb_build_object('type','text','category','medical')
      when 'medical_notes' then jsonb_build_object('type','text','category','medical')
      when 'emergency_first_name' then jsonb_build_object('type','text','category','emergency')
      when 'emergency_last_name' then jsonb_build_object('type','text','category','emergency')
      when 'emergency_relationship' then jsonb_build_object('type','text','category','emergency')
      when 'emergency_phone' then jsonb_build_object('type','text','category','emergency')
      when 'emergency_email' then jsonb_build_object('type','text','category','emergency')
      when 'injury_photo' then jsonb_build_object('type','document','category','attachments','document_category','injury_photo')
      when 'emergency_report' then jsonb_build_object('type','document','category','attachments','document_category','emergency_report')
      when 'medical_certificate' then jsonb_build_object('type','document','category','attachments','document_category','medical_certificate')
      when 'additional_document' then jsonb_build_object('type','document','category','attachments','document_category','additional_document')
    end
  end;
$$;

create or replace function public.insurance_information_request_current_value(
  p_request_id uuid,
  p_field_key text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_request public.insurance_information_requests;
  v_record public.insurance_case_file_records;
  v_emergency public.insurance_case_file_records;
begin
  select * into v_request
  from public.insurance_information_requests where id = p_request_id;
  if not found then return 'null'::jsonb; end if;

  select * into v_record
  from public.insurance_case_file_records where id = v_request.record_id;
  select * into v_emergency
  from public.insurance_case_file_records
  where claim_id = v_request.claim_id
    and record_type = 'emergency_contact' and source_index = 0;

  return case p_field_key
    when 'first_name' then to_jsonb(v_record.first_name)
    when 'last_name' then to_jsonb(v_record.last_name)
    when 'birth_date' then to_jsonb(v_record.birth_date)
    when 'gender' then to_jsonb(v_record.gender)
    when 'nationality' then to_jsonb(v_record.nationality)
    when 'spoken_language' then to_jsonb(v_record.spoken_language)
    when 'phone' then to_jsonb(v_record.phone)
    when 'email' then to_jsonb(v_record.email)
    when 'street' then to_jsonb(v_record.street)
    when 'postal_code' then to_jsonb(v_record.postal_code)
    when 'city' then to_jsonb(v_record.city)
    when 'country' then to_jsonb(v_record.country)
    when 'document_type' then to_jsonb(v_record.document_type)
    when 'document_number' then to_jsonb(v_record.document_number)
    when 'document_expiry' then to_jsonb(v_record.document_expiry)
    when 'witness_statement' then to_jsonb(v_record.witness_statement)
    when 'digital_signature_text' then to_jsonb(v_record.digital_signature_text)
    when 'injury_severity' then to_jsonb(v_record.injury_severity)
    when 'body_part' then to_jsonb(v_record.body_part)
    when 'ambulance_attended' then to_jsonb(v_record.ambulance_attended)
    when 'hospitalized' then to_jsonb(v_record.hospitalized)
    when 'hospital_name' then to_jsonb(v_record.hospital_name)
    when 'doctor_name' then to_jsonb(v_record.doctor_name)
    when 'hospital_case_number' then to_jsonb(v_record.hospital_case_number)
    when 'medical_notes' then to_jsonb(v_record.notes)
    when 'emergency_first_name' then to_jsonb(v_emergency.first_name)
    when 'emergency_last_name' then to_jsonb(v_emergency.last_name)
    when 'emergency_relationship' then to_jsonb(v_emergency.relationship)
    when 'emergency_phone' then to_jsonb(v_emergency.phone)
    when 'emergency_email' then to_jsonb(v_emergency.email)
    else 'null'::jsonb
  end;
end;
$$;

create or replace function public.insurance_information_request_effective_value(
  p_request_id uuid,
  p_field_key text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_value public.insurance_information_request_values;
begin
  select * into v_value
  from public.insurance_information_request_values
  where request_id = p_request_id and field_key = p_field_key;
  if found then
    if v_value.value_boolean is not null then return to_jsonb(v_value.value_boolean); end if;
    if v_value.value_date is not null then return to_jsonb(v_value.value_date); end if;
    return to_jsonb(v_value.value_text);
  end if;
  return public.insurance_information_request_current_value(p_request_id, p_field_key);
end;
$$;

create or replace function public.expire_insurance_information_requests(p_claim_id text default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_request record;
begin
  for v_request in
    update public.insurance_information_requests
      set status = 'expired', updated_at = now()
    where status in ('draft', 'pending', 'opened')
      and expires_at <= now()
      and (p_claim_id is null or claim_id = p_claim_id)
    returning id, claim_id, record_id
  loop
    v_count := v_count + 1;
    insert into public.insurance_information_request_audit (
      request_id, claim_id, record_id, event_type, actor_kind
    ) values (
      v_request.id, v_request.claim_id, v_request.record_id,
      'information_request_expired', 'system'
    );
  end loop;
  return v_count;
end;
$$;

create or replace function public.create_insurance_information_request(
  p_claim_id text,
  p_record_id uuid,
  p_field_keys text[],
  p_expires_days integer,
  p_message text,
  p_locale text,
  p_replace_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_record public.insurance_case_file_records;
  v_request public.insurance_information_requests;
  v_token text;
  v_field_key text;
  v_definition jsonb;
  v_sort integer := 0;
begin
  if not public.is_claim_insurance_editor(p_claim_id) then
    raise exception 'insurance_claim_participant_required_for_information_request';
  end if;
  if p_expires_days not in (3, 7, 14) then
    raise exception 'invalid_information_request_expiry';
  end if;
  if coalesce(array_length(p_field_keys, 1), 0) = 0 then
    raise exception 'information_request_items_required';
  end if;
  if cardinality(p_field_keys) > 32 or (
    select count(distinct field_key) <> cardinality(p_field_keys)
    from unnest(p_field_keys) as requested(field_key)
  ) then
    raise exception 'invalid_information_request_items';
  end if;
  if length(coalesce(p_message, '')) > 1200 then
    raise exception 'information_request_message_too_long';
  end if;

  select * into v_record from public.insurance_case_file_records
  where id = p_record_id and claim_id = p_claim_id
    and record_type in ('witness', 'injured');
  if not found then raise exception 'information_request_record_not_found'; end if;

  perform public.expire_insurance_information_requests(p_claim_id);
  if exists (
    select 1 from public.insurance_information_requests
    where record_id = p_record_id and status in ('draft', 'pending', 'opened')
  ) then
    if not coalesce(p_replace_active, false) then
      raise exception 'active_information_request_exists';
    end if;
    insert into public.insurance_information_request_audit (
      request_id, claim_id, record_id, event_type, actor_kind, actor_user_id,
      metadata
    )
    select id, claim_id, record_id, 'information_request_cancelled',
      'insurance', auth.uid(), jsonb_build_object('reason', 'replaced')
    from public.insurance_information_requests
    where record_id = p_record_id and status in ('draft', 'pending', 'opened');
    update public.insurance_information_requests
      set status = 'cancelled', cancelled_at = now(), updated_at = now(),
          updated_by = auth.uid()
    where record_id = p_record_id and status in ('draft', 'pending', 'opened');
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.insurance_information_requests (
    claim_id, record_id, record_type, source_index, insurance_user_id,
    recipient_email, recipient_phone, token_hash, status,
    insurance_message, locale, expires_at
  ) values (
    p_claim_id, v_record.id, v_record.record_type, v_record.source_index,
    auth.uid(), nullif(btrim(v_record.email), ''), nullif(btrim(v_record.phone), ''),
    public.insurance_information_request_hash(v_token), 'pending',
    nullif(btrim(p_message), ''),
    case when p_locale in ('it','de','fr','en') then p_locale else 'it' end,
    now() + make_interval(days => p_expires_days)
  ) returning * into v_request;

  foreach v_field_key in array p_field_keys loop
    v_definition := public.insurance_information_request_field_definition(
      v_record.record_type, v_field_key
    );
    if v_definition is null then
      raise exception 'invalid_information_request_field:%', v_field_key;
    end if;
    v_sort := v_sort + 1;
    insert into public.insurance_information_request_items (
      request_id, field_key, field_type, category,
      requested_document_category, sort_order
    ) values (
      v_request.id, v_field_key, v_definition ->> 'type',
      v_definition ->> 'category', v_definition ->> 'document_category', v_sort
    ) on conflict (request_id, field_key) do nothing;
  end loop;

  insert into public.insurance_information_request_audit (
    request_id, claim_id, record_id, event_type, actor_kind, actor_user_id,
    metadata
  ) values (
    v_request.id, p_claim_id, p_record_id,
    'information_request_created', 'insurance', auth.uid(),
    jsonb_build_object('item_count', v_sort, 'expires_at', v_request.expires_at)
  );

  return jsonb_build_object(
    'request', to_jsonb(v_request) - 'token_hash',
    'token', v_token
  );
end;
$$;

create or replace function public.get_insurance_information_requests(p_claim_id text)
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
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc), '[]'::jsonb)
  into v_result
  from (
    select r.id, r.claim_id, r.record_id, r.record_type, r.source_index,
      r.recipient_email, r.recipient_phone, r.status, r.insurance_message,
      r.locale, r.expires_at, r.first_opened_at, r.last_opened_at,
      r.submitted_at, r.cancelled_at, r.created_at,
      nullif(btrim(concat_ws(' ', f.first_name, f.last_name)), '') as recipient_name,
      (select count(*) from public.insurance_information_request_items i
        where i.request_id = r.id) as item_count,
      (select count(*) from public.insurance_information_request_items i
        where i.request_id = r.id and (
          (i.field_type = 'document' and exists (
            select 1 from public.insurance_information_request_attachments a
            where a.request_id = r.id and a.field_key = i.field_key
              and a.upload_status in ('uploaded', 'transferred')
          )) or
          (i.field_type <> 'document' and
            public.insurance_information_request_effective_value(r.id, i.field_key)
              is distinct from 'null'::jsonb and
            public.insurance_information_request_effective_value(r.id, i.field_key)
              <> '""'::jsonb)
        )) as completed_item_count
    from public.insurance_information_requests r
    join public.insurance_case_file_records f on f.id = r.record_id
    where r.claim_id = p_claim_id
  ) q;
  return v_result;
end;
$$;

create or replace function public.rotate_insurance_information_request_token(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_request public.insurance_information_requests;
  v_token text;
begin
  select * into v_request from public.insurance_information_requests
  where id = p_request_id for update;
  if not found or not public.is_claim_insurance_editor(v_request.claim_id) then
    raise exception 'information_request_not_authorized';
  end if;
  if v_request.status not in ('draft', 'pending', 'opened')
      or v_request.expires_at <= now() then
    raise exception 'information_request_not_active';
  end if;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  update public.insurance_information_requests
    set token_hash = public.insurance_information_request_hash(v_token),
        status = 'pending', updated_at = now(), updated_by = auth.uid()
  where id = p_request_id returning * into v_request;
  insert into public.insurance_information_request_audit (
    request_id, claim_id, record_id, event_type, actor_kind, actor_user_id
  ) values (
    v_request.id, v_request.claim_id, v_request.record_id,
    'information_request_link_rotated', 'insurance', auth.uid()
  );
  return jsonb_build_object('request', to_jsonb(v_request) - 'token_hash', 'token', v_token);
end;
$$;

create or replace function public.cancel_insurance_information_request(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_request public.insurance_information_requests;
begin
  select * into v_request from public.insurance_information_requests
  where id = p_request_id for update;
  if not found or not public.is_claim_insurance_editor(v_request.claim_id) then
    raise exception 'information_request_not_authorized';
  end if;
  if v_request.status not in ('draft', 'pending', 'opened') then
    raise exception 'information_request_not_active';
  end if;
  update public.insurance_information_requests
    set status = 'cancelled', cancelled_at = now(), updated_at = now(),
        updated_by = auth.uid()
  where id = p_request_id returning * into v_request;
  insert into public.insurance_information_request_audit (
    request_id, claim_id, record_id, event_type, actor_kind, actor_user_id
  ) values (
    v_request.id, v_request.claim_id, v_request.record_id,
    'information_request_cancelled', 'insurance', auth.uid()
  );
  return to_jsonb(v_request) - 'token_hash';
end;
$$;

create or replace function public.get_public_insurance_information_request(p_token text)
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
  if auth.uid() is null then return jsonb_build_object('state', 'invalid'); end if;
  select * into v_request from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token)
  for update;
  if not found then return jsonb_build_object('state', 'invalid'); end if;
  if v_request.status = 'submitted' then return jsonb_build_object('state', 'submitted'); end if;
  if v_request.status = 'cancelled' then return jsonb_build_object('state', 'cancelled'); end if;
  if v_request.status = 'expired' or v_request.expires_at <= now() then
    if v_request.status <> 'expired' then
      update public.insurance_information_requests set status = 'expired', updated_at = now()
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
    set status = 'opened', first_opened_at = coalesce(first_opened_at, now()),
        last_opened_at = now(), updated_at = now(), updated_by = auth.uid()
  where id = v_request.id;
  if v_request.first_opened_at is null then
    insert into public.insurance_information_request_audit (
      request_id, claim_id, record_id, event_type, actor_kind, actor_user_id
    ) values (
      v_request.id, v_request.claim_id, v_request.record_id,
      'information_request_opened', 'recipient_token', auth.uid()
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
  ), '[]'::jsonb) into v_items
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
  where a.request_id = v_request.id and a.upload_status = 'uploaded';

  select coalesce(nullif(btrim(p.company_name), ''), nullif(btrim(p.display_name), ''),
    'Insurance') into v_company
  from public.profiles p where p.id = v_request.insurance_user_id;

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
  v_request public.insurance_information_requests;
  v_item public.insurance_information_request_items;
  v_entry record;
  v_text text;
  v_max_length integer;
begin
  if auth.uid() is null then raise exception 'information_request_auth_required'; end if;
  select * into v_request from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token) for update;
  if not found then raise exception 'information_request_invalid'; end if;
  if v_request.status not in ('draft', 'pending', 'opened')
      or v_request.expires_at <= now() then
    raise exception 'information_request_not_editable';
  end if;
  if jsonb_typeof(p_values) <> 'object' then raise exception 'invalid_draft_values'; end if;

  for v_entry in select * from jsonb_each(p_values) loop
    select * into v_item from public.insurance_information_request_items
    where request_id = v_request.id and field_key = v_entry.key
      and field_type <> 'document';
    if not found then raise exception 'field_not_requested:%', v_entry.key; end if;
    v_text := nullif(btrim(v_entry.value #>> '{}'), '');
    v_max_length := 1000;
    if v_entry.key in (
      'witness_statement', 'digital_signature_text', 'medical_notes'
    ) then
      v_max_length := 10000;
    end if;
    if v_text is not null and length(v_text) > v_max_length then
      raise exception 'information_request_value_too_long:%', v_entry.key;
    end if;
    insert into public.insurance_information_request_values (
      request_id, field_key, value_text, value_boolean, value_date, updated_at
    ) values (
      v_request.id, v_entry.key,
      case when v_item.field_type in ('text') then v_text end,
      case when v_item.field_type in ('boolean','confirmation') and v_text is not null
        then v_text::boolean end,
      case when v_item.field_type = 'date' and v_text is not null then v_text::date end,
      now()
    ) on conflict (request_id, field_key) do update set
      value_text = excluded.value_text,
      value_boolean = excluded.value_boolean,
      value_date = excluded.value_date,
      updated_at = now();
  end loop;
  update public.insurance_information_requests
    set status = 'draft', last_opened_at = now(), updated_at = now(),
        updated_by = auth.uid()
  where id = v_request.id;
  insert into public.insurance_information_request_audit (
    request_id, claim_id, record_id, event_type, actor_kind, actor_user_id,
    metadata
  ) values (
    v_request.id, v_request.claim_id, v_request.record_id,
    'information_request_draft_saved', 'recipient_token', auth.uid(),
    jsonb_build_object('field_count', (select count(*) from jsonb_object_keys(p_values)))
  );
  return jsonb_build_object('saved', true, 'saved_at', now());
end;
$$;

create or replace function public.prepare_public_information_request_attachment_upload(
  p_token text,
  p_field_key text,
  p_file_name text,
  p_mime_type text,
  p_byte_size bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_request public.insurance_information_requests;
  v_item public.insurance_information_request_items;
  v_attachment public.insurance_information_request_attachments;
  v_safe_name text;
begin
  if auth.uid() is null then raise exception 'information_request_auth_required'; end if;
  select * into v_request from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token) for update;
  if not found or v_request.status not in ('draft','pending','opened')
      or v_request.expires_at <= now() then
    raise exception 'information_request_not_editable';
  end if;
  select * into v_item from public.insurance_information_request_items
  where request_id = v_request.id and field_key = p_field_key
    and field_type = 'document';
  if not found then raise exception 'document_not_requested'; end if;
  if p_byte_size < 1 or p_byte_size > 20971520 then raise exception 'file_size_not_allowed'; end if;
  if lower(coalesce(p_mime_type,'')) not in ('application/pdf','image/jpeg','image/png') then
    raise exception 'file_type_not_allowed';
  end if;
  if lower(coalesce(p_file_name, '')) !~ '\.(pdf|jpg|jpeg|png)$' then
    raise exception 'file_extension_not_allowed';
  end if;
  v_safe_name := left(
    regexp_replace(coalesce(p_file_name, ''), '[^A-Za-z0-9._-]+', '_', 'g'),
    180
  );
  if v_safe_name = '' then v_safe_name := 'documento'; end if;
  insert into public.insurance_information_request_attachments (
    request_id, field_key, category, object_path, file_name, mime_type, byte_size
  ) values (
    v_request.id, p_field_key, v_item.requested_document_category,
    v_request.claim_id || '/information_requests/' || v_request.id::text || '/' ||
      v_request.record_type || '/' || extensions.gen_random_uuid()::text || '/' || v_safe_name,
    v_safe_name, lower(p_mime_type), p_byte_size
  ) returning * into v_attachment;
  return jsonb_build_object(
    'request_id', v_request.id,
    'attachment_id', v_attachment.id,
    'bucket', v_attachment.bucket,
    'object_path', v_attachment.object_path
  );
end;
$$;

create or replace function public.abort_public_information_request_attachment_upload(
  p_token text,
  p_attachment_id uuid,
  p_object_path text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.insurance_information_requests;
begin
  select * into v_request from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token) for update;
  if not found or v_request.status not in ('draft','pending','opened')
      or v_request.expires_at <= now() then
    raise exception 'information_request_not_editable';
  end if;
  delete from public.insurance_information_request_attachments
  where id = p_attachment_id and request_id = v_request.id
    and object_path = p_object_path and upload_status = 'pending';
end;
$$;

create or replace function public.finalize_public_information_request_attachment_upload(
  p_token text,
  p_attachment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.insurance_information_requests;
  v_attachment public.insurance_information_request_attachments;
begin
  select * into v_request from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token) for update;
  if not found or v_request.status not in ('draft','pending','opened')
      or v_request.expires_at <= now() then raise exception 'information_request_not_editable'; end if;
  update public.insurance_information_request_attachments
    set upload_status = 'uploaded', uploaded_at = now()
  where id = p_attachment_id and request_id = v_request.id
    and upload_status = 'pending'
  returning * into v_attachment;
  if not found then raise exception 'information_request_attachment_not_found'; end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = v_attachment.bucket and o.name = v_attachment.object_path
  ) then
    raise exception 'information_request_storage_object_missing';
  end if;
  insert into public.insurance_information_request_audit (
    request_id, claim_id, record_id, event_type, actor_kind, actor_user_id,
    metadata
  ) values (
    v_request.id, v_request.claim_id, v_request.record_id,
    'information_request_attachment_uploaded', 'recipient_token', auth.uid(),
    jsonb_build_object('attachment_id', v_attachment.id, 'category', v_attachment.category)
  );
  return to_jsonb(v_attachment) - 'object_path';
end;
$$;

create or replace function public.prepare_public_information_request_attachment_delete(
  p_token text,
  p_attachment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.insurance_information_requests;
  v_attachment public.insurance_information_request_attachments;
begin
  select * into v_request from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token) for update;
  if not found or v_request.status not in ('draft','pending','opened')
      or v_request.expires_at <= now() then raise exception 'information_request_not_editable'; end if;
  select * into v_attachment from public.insurance_information_request_attachments
  where id = p_attachment_id and request_id = v_request.id
    and upload_status = 'uploaded';
  if not found then raise exception 'information_request_attachment_not_found'; end if;
  return jsonb_build_object('bucket', v_attachment.bucket, 'object_path', v_attachment.object_path);
end;
$$;

create or replace function public.finalize_public_information_request_attachment_delete(
  p_token text,
  p_attachment_id uuid,
  p_object_path text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.insurance_information_requests;
  v_attachment public.insurance_information_request_attachments;
begin
  select * into v_request from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token) for update;
  if not found or v_request.status not in ('draft','pending','opened')
      or v_request.expires_at <= now() then raise exception 'information_request_not_editable'; end if;
  if exists (
    select 1 from public.insurance_information_request_attachments a
    join storage.objects o
      on o.bucket_id = a.bucket and o.name = a.object_path
    where a.id = p_attachment_id and a.request_id = v_request.id
  ) then
    raise exception 'information_request_storage_object_still_exists';
  end if;
  delete from public.insurance_information_request_attachments
  where id = p_attachment_id and request_id = v_request.id
    and object_path = p_object_path and upload_status = 'uploaded'
  returning * into v_attachment;
  if not found then raise exception 'information_request_attachment_not_found_or_changed'; end if;
  insert into public.insurance_information_request_audit (
    request_id, claim_id, record_id, event_type, actor_kind, actor_user_id,
    metadata
  ) values (
    v_request.id, v_request.claim_id, v_request.record_id,
    'information_request_attachment_deleted', 'recipient_token', auth.uid(),
    jsonb_build_object('attachment_id', v_attachment.id, 'category', v_attachment.category)
  );
  return jsonb_build_object('deleted', true);
end;
$$;

create or replace function public.insurance_case_file_before_write()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_completed integer := 0;
  v_required integer := 0;
  v_external_request_id uuid;
  v_external_allowed boolean := false;
begin
  if auth.uid() is null then raise exception 'authenticated_user_required'; end if;
  begin
    v_external_request_id := nullif(
      current_setting('app.insurance_information_request_id', true), ''
    )::uuid;
  exception when others then
    v_external_request_id := null;
  end;
  if v_external_request_id is not null then
    select exists (
      select 1 from public.insurance_information_requests r
      where r.id = v_external_request_id and r.claim_id = new.claim_id
        and r.status in ('pending','opened') and r.expires_at > now()
        and (
          r.record_id = new.id or
          (r.record_type = 'injured' and new.record_type = 'emergency_contact')
        )
    ) into v_external_allowed;
  end if;
  if not public.is_claim_insurance_editor(new.claim_id) and not v_external_allowed then
    raise exception 'insurance_claim_participant_required_for_case_file';
  end if;

  new.updated_at := now();
  new.updated_by := auth.uid();
  new.last_update_source := case when v_external_allowed
    then 'secure_information_request' else 'insurance_manual' end;
  new.last_information_request_id := case when v_external_allowed
    then v_external_request_id else null end;
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.created_by := auth.uid();
  end if;

  if new.record_type = 'witness' then
    v_required := 10;
    v_completed :=
      (nullif(btrim(new.first_name), '') is not null)::int +
      (nullif(btrim(new.last_name), '') is not null)::int +
      (new.birth_date is not null)::int +
      (nullif(btrim(new.nationality), '') is not null)::int +
      (nullif(btrim(new.spoken_language), '') is not null)::int +
      (nullif(btrim(new.phone), '') is not null)::int +
      (nullif(btrim(new.email), '') is not null)::int +
      (nullif(btrim(new.street), '') is not null)::int +
      (nullif(btrim(new.document_number), '') is not null)::int +
      (nullif(btrim(new.witness_statement), '') is not null)::int;
  elsif new.record_type = 'injured' then
    v_required := 12;
    v_completed :=
      (nullif(btrim(new.first_name), '') is not null)::int +
      (nullif(btrim(new.last_name), '') is not null)::int +
      (new.birth_date is not null)::int +
      (nullif(btrim(new.gender), '') is not null)::int +
      (nullif(btrim(new.nationality), '') is not null)::int +
      (nullif(btrim(new.phone), '') is not null)::int +
      (nullif(btrim(new.email), '') is not null)::int +
      (nullif(btrim(new.street), '') is not null)::int +
      (nullif(btrim(new.injury_severity), '') is not null)::int +
      (nullif(btrim(new.body_part), '') is not null)::int +
      (new.ambulance_attended is not null)::int +
      (new.hospitalized is not null)::int;
  else
    v_required := 5;
    v_completed :=
      (nullif(btrim(new.first_name), '') is not null)::int +
      (nullif(btrim(new.last_name), '') is not null)::int +
      (nullif(btrim(new.relationship), '') is not null)::int +
      (nullif(btrim(new.phone), '') is not null)::int +
      (nullif(btrim(new.email), '') is not null)::int;
  end if;
  new.completeness_status := case
    when v_completed = 0 then 'missing'
    when v_completed >= v_required then 'complete'
    else 'partial'
  end;
  return new;
end;
$$;

-- Preserve the existing dossier audit behavior for manual insurance edits, but
-- never copy personal or medical values into the audit row when data arrives
-- from a secure information request. The request audit remains metadata-only.
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
  v_external_submission boolean := false;
  v_external_request_id uuid;
  v_external_completeness text;
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
      v_external_submission := old.last_update_source = 'secure_information_request';
      v_external_request_id := old.last_information_request_id;
      v_external_completeness := old.completeness_status;
    else
      v_claim_id := new.claim_id;
      v_record_id := new.id;
      v_actor_user_id := coalesce(auth.uid(), new.updated_by);
      v_external_submission := new.last_update_source = 'secure_information_request';
      v_external_request_id := new.last_information_request_id;
      v_external_completeness := new.completeness_status;
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

  if v_external_submission then
    v_old := case when tg_op in ('UPDATE', 'DELETE') then jsonb_build_object(
      'id', v_record_id,
      'claim_id', v_claim_id,
      'record_type', old.record_type,
      'source_index', old.source_index,
      'completeness_status', old.completeness_status,
      'last_update_source', old.last_update_source,
      'last_information_request_id', old.last_information_request_id
    ) end;
    v_new := case when tg_op in ('INSERT', 'UPDATE') then jsonb_build_object(
      'id', v_record_id,
      'claim_id', v_claim_id,
      'record_type', new.record_type,
      'source_index', new.source_index,
      'completeness_status', new.completeness_status,
      'last_update_source', new.last_update_source,
      'last_information_request_id', new.last_information_request_id
    ) end;
    v_changed := jsonb_build_object(
      'source', 'secure_information_request',
      'request_id', v_external_request_id,
      'completeness_status', v_external_completeness
    );
  elsif tg_op = 'UPDATE' then
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
  v_request public.insurance_information_requests;
  v_record public.insurance_case_file_records;
  v_emergency public.insurance_case_file_records;
  v_item public.insurance_information_request_items;
  v_value jsonb;
  v_text text;
begin
  if auth.uid() is null then raise exception 'information_request_auth_required'; end if;
  if not coalesce(p_confirm_truth, false) or not coalesce(p_confirm_privacy, false) then
    raise exception 'information_request_confirmations_required';
  end if;
  select * into v_request from public.insurance_information_requests
  where token_hash = public.insurance_information_request_hash(p_token) for update;
  if not found then raise exception 'information_request_invalid'; end if;
  if v_request.status not in ('draft','pending','opened')
      or v_request.expires_at <= now() then raise exception 'information_request_not_editable'; end if;
  select * into v_record from public.insurance_case_file_records
  where id = v_request.record_id and claim_id = v_request.claim_id
    and record_type = v_request.record_type;
  if not found then raise exception 'information_request_record_not_found'; end if;

  for v_item in select * from public.insurance_information_request_items
    where request_id = v_request.id and required order by sort_order
  loop
    if v_item.field_type = 'document' then
      if not exists (
        select 1 from public.insurance_information_request_attachments a
        join storage.objects o
          on o.bucket_id = a.bucket and o.name = a.object_path
        where a.request_id = v_request.id and a.field_key = v_item.field_key
          and a.upload_status = 'uploaded'
      ) then raise exception 'required_document_missing:%', v_item.field_key; end if;
    else
      v_value := public.insurance_information_request_effective_value(
        v_request.id, v_item.field_key
      );
      if v_value is null or v_value = 'null'::jsonb or v_value = '""'::jsonb then
        raise exception 'required_information_missing:%', v_item.field_key;
      end if;
      if v_item.field_type = 'confirmation' and v_value <> 'true'::jsonb then
        raise exception 'required_confirmation_missing:%', v_item.field_key;
      end if;
    end if;
  end loop;

  select * into v_emergency from public.insurance_case_file_records
  where claim_id = v_request.claim_id and record_type = 'emergency_contact'
    and source_index = 0;

  for v_item in select * from public.insurance_information_request_items
    where request_id = v_request.id and field_type <> 'document'
  loop
    v_value := public.insurance_information_request_effective_value(
      v_request.id, v_item.field_key
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
      when 'digital_signature_text' then v_record.digital_signature_text := v_text;
      when 'injury_severity' then v_record.injury_severity := v_text;
      when 'body_part' then v_record.body_part := v_text;
      when 'ambulance_attended' then v_record.ambulance_attended := v_text::boolean;
      when 'hospitalized' then v_record.hospitalized := v_text::boolean;
      when 'hospital_name' then v_record.hospital_name := v_text;
      when 'doctor_name' then v_record.doctor_name := v_text;
      when 'hospital_case_number' then v_record.hospital_case_number := v_text;
      when 'medical_notes' then v_record.notes := v_text;
      when 'emergency_first_name' then v_emergency.first_name := v_text;
      when 'emergency_last_name' then v_emergency.last_name := v_text;
      when 'emergency_relationship' then v_emergency.relationship := v_text;
      when 'emergency_phone' then v_emergency.phone := v_text;
      when 'emergency_email' then v_emergency.email := v_text;
      else v_text := v_text;
    end case;
  end loop;

  perform set_config('app.insurance_information_request_id', v_request.id::text, true);
  update public.insurance_case_file_records set
    first_name = v_record.first_name, last_name = v_record.last_name,
    birth_date = v_record.birth_date, gender = v_record.gender,
    nationality = v_record.nationality, spoken_language = v_record.spoken_language,
    phone = v_record.phone, email = v_record.email, street = v_record.street,
    postal_code = v_record.postal_code, city = v_record.city, country = v_record.country,
    document_type = v_record.document_type, document_number = v_record.document_number,
    document_expiry = v_record.document_expiry,
    witness_statement = v_record.witness_statement,
    digital_signature_text = v_record.digital_signature_text,
    injury_severity = v_record.injury_severity, body_part = v_record.body_part,
    ambulance_attended = v_record.ambulance_attended,
    hospitalized = v_record.hospitalized, hospital_name = v_record.hospital_name,
    doctor_name = v_record.doctor_name,
    hospital_case_number = v_record.hospital_case_number, notes = v_record.notes
  where id = v_record.id;

  if v_request.record_type = 'injured' and exists (
    select 1 from public.insurance_information_request_items
    where request_id = v_request.id and category = 'emergency'
  ) then
    insert into public.insurance_case_file_records as r (
      id, claim_id, record_type, source_index, first_name, last_name,
      relationship, phone, email
    ) values (
      coalesce(v_emergency.id, extensions.gen_random_uuid()), v_request.claim_id,
      'emergency_contact', 0, v_emergency.first_name, v_emergency.last_name,
      v_emergency.relationship, v_emergency.phone, v_emergency.email
    ) on conflict (claim_id, record_type, source_index) do update set
      first_name = excluded.first_name, last_name = excluded.last_name,
      relationship = excluded.relationship, phone = excluded.phone,
      email = excluded.email;
  end if;

  insert into public.insurance_case_file_attachments (
    claim_id, record_id, category, bucket, object_path,
    file_name, mime_type, byte_size, created_by
  ) select
    v_request.claim_id, v_request.record_id, a.category, a.bucket, a.object_path,
    a.file_name, a.mime_type, a.byte_size, auth.uid()
  from public.insurance_information_request_attachments a
  where a.request_id = v_request.id and a.upload_status = 'uploaded'
  on conflict (object_path) do nothing;
  update public.insurance_information_request_attachments
    set upload_status = 'transferred'
  where request_id = v_request.id and upload_status = 'uploaded';

  update public.insurance_information_requests
    set status = 'submitted', submitted_at = now(), updated_at = now(),
        updated_by = auth.uid()
  where id = v_request.id;
  insert into public.insurance_information_request_audit (
    request_id, claim_id, record_id, event_type, actor_kind, actor_user_id,
    metadata
  ) values (
    v_request.id, v_request.claim_id, v_request.record_id,
    'information_request_submitted', 'recipient_token', auth.uid(),
    jsonb_build_object(
      'item_count', (select count(*) from public.insurance_information_request_items
        where request_id = v_request.id),
      'attachment_count', (select count(*) from public.insurance_information_request_attachments
        where request_id = v_request.id),
      'truth_confirmed', true,
      'privacy_confirmed', true
    )
  );
  return jsonb_build_object('submitted', true, 'submitted_at', now());
end;
$$;

create or replace function public.get_insurance_information_request_delivery(
  p_request_id uuid,
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.insurance_information_requests;
  v_company text;
  v_contact text;
begin
  select * into v_request from public.insurance_information_requests
  where id = p_request_id
    and token_hash = public.insurance_information_request_hash(p_token);
  if not found or not public.is_claim_insurance_editor(v_request.claim_id) then
    raise exception 'information_request_not_authorized';
  end if;
  select coalesce(nullif(btrim(company_name), ''), nullif(btrim(display_name), ''),
    'Insurance'), email
  into v_company, v_contact
  from public.profiles where id = auth.uid();
  return jsonb_build_object(
    'request_id', v_request.id,
    'recipient_email', v_request.recipient_email,
    'company_name', v_company,
    'insurance_contact', v_contact,
    'claim_reference', upper(left(v_request.claim_id, 8)),
    'expires_at', v_request.expires_at,
    'locale', v_request.locale
  );
end;
$$;

create or replace function public.mark_insurance_information_request_sent(
  p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_request public.insurance_information_requests;
begin
  select * into v_request from public.insurance_information_requests where id = p_request_id;
  if not found or not public.is_claim_insurance_editor(v_request.claim_id) then
    raise exception 'information_request_not_authorized';
  end if;
  insert into public.insurance_information_request_audit (
    request_id, claim_id, record_id, event_type, actor_kind, actor_user_id
  ) values (
    v_request.id, v_request.claim_id, v_request.record_id,
    'information_request_sent', 'insurance', auth.uid()
  );
end;
$$;

revoke all on function public.insurance_information_request_hash(text) from public;
revoke all on function public.insurance_information_request_field_definition(text, text) from public;
revoke all on function public.insurance_information_request_current_value(uuid, text) from public;
revoke all on function public.insurance_information_request_effective_value(uuid, text) from public;
revoke all on function public.expire_insurance_information_requests(text) from public;

revoke all on function public.create_insurance_information_request(
  text, uuid, text[], integer, text, text, boolean
) from public;
revoke all on function public.get_insurance_information_requests(text) from public;
revoke all on function public.rotate_insurance_information_request_token(uuid) from public;
revoke all on function public.cancel_insurance_information_request(uuid) from public;
revoke all on function public.get_public_insurance_information_request(text) from public;
revoke all on function public.save_public_insurance_information_request_draft(text, jsonb) from public;
revoke all on function public.prepare_public_information_request_attachment_upload(
  text, text, text, text, bigint
) from public;
revoke all on function public.abort_public_information_request_attachment_upload(
  text, uuid, text
) from public;
revoke all on function public.finalize_public_information_request_attachment_upload(
  text, uuid
) from public;
revoke all on function public.prepare_public_information_request_attachment_delete(
  text, uuid
) from public;
revoke all on function public.finalize_public_information_request_attachment_delete(
  text, uuid, text
) from public;
revoke all on function public.submit_public_insurance_information_request(
  text, boolean, boolean
) from public;
revoke all on function public.get_insurance_information_request_delivery(uuid, text) from public;
revoke all on function public.mark_insurance_information_request_sent(uuid) from public;

grant execute on function public.create_insurance_information_request(
  text, uuid, text[], integer, text, text, boolean
) to authenticated;
grant execute on function public.get_insurance_information_requests(text) to authenticated;
grant execute on function public.rotate_insurance_information_request_token(uuid) to authenticated;
grant execute on function public.cancel_insurance_information_request(uuid) to authenticated;
grant execute on function public.get_public_insurance_information_request(text) to authenticated;
grant execute on function public.save_public_insurance_information_request_draft(text, jsonb) to authenticated;
grant execute on function public.prepare_public_information_request_attachment_upload(
  text, text, text, text, bigint
) to authenticated;
grant execute on function public.abort_public_information_request_attachment_upload(
  text, uuid, text
) to authenticated;
grant execute on function public.finalize_public_information_request_attachment_upload(
  text, uuid
) to authenticated;
grant execute on function public.prepare_public_information_request_attachment_delete(
  text, uuid
) to authenticated;
grant execute on function public.finalize_public_information_request_attachment_delete(
  text, uuid, text
) to authenticated;
grant execute on function public.submit_public_insurance_information_request(
  text, boolean, boolean
) to authenticated;
grant execute on function public.get_insurance_information_request_delivery(uuid, text) to authenticated;
grant execute on function public.mark_insurance_information_request_sent(uuid) to authenticated;

comment on table public.insurance_information_requests is
  'Tokenized requests created only by the assigned insurance editor.';
comment on table public.insurance_information_request_values is
  'Normalized draft values supplied through a secure request; no claim payload JSON storage.';
comment on table public.insurance_information_request_audit is
  'Metadata-only audit trail. Sensitive field values and document numbers are intentionally excluded.';

commit;
