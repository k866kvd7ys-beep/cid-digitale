begin;

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.insurance_case_file_records (
  id uuid primary key default extensions.gen_random_uuid(),
  claim_id text not null references public.claims(id) on delete cascade,
  record_type text not null check (
    record_type in ('witness', 'injured', 'emergency_contact')
  ),
  source_index integer not null default 0 check (source_index >= 0),
  first_name text,
  last_name text,
  birth_date date,
  gender text,
  nationality text,
  spoken_language text,
  phone text,
  email text,
  street text,
  postal_code text,
  city text,
  country text,
  document_type text,
  document_number text,
  document_expiry date,
  witness_statement text,
  digital_signature_text text,
  injury_severity text check (
    injury_severity is null or injury_severity in (
      'none', 'minor', 'moderate', 'severe', 'critical'
    )
  ),
  body_part text check (
    body_part is null or body_part in (
      'head', 'neck', 'chest', 'back', 'arm', 'hand',
      'abdomen', 'leg', 'foot', 'other'
    )
  ),
  ambulance_attended boolean,
  hospitalized boolean,
  hospital_name text,
  doctor_name text,
  hospital_case_number text,
  relationship text,
  notes text,
  completeness_status text not null default 'missing' check (
    completeness_status in ('missing', 'partial', 'complete')
  ),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  updated_at timestamptz not null default now(),
  updated_by uuid not null default auth.uid(),
  unique (claim_id, record_type, source_index)
);

create index if not exists insurance_case_file_records_claim_idx
  on public.insurance_case_file_records (claim_id, record_type, source_index);

create table if not exists public.insurance_case_file_attachments (
  id uuid primary key default extensions.gen_random_uuid(),
  claim_id text not null references public.claims(id) on delete cascade,
  record_id uuid not null references public.insurance_case_file_records(id)
    on delete cascade,
  category text not null check (
    category in (
      'document_photo', 'signed_statement', 'digital_signature',
      'injury_photo', 'emergency_report', 'medical_certificate',
      'additional_document'
    )
  ),
  bucket text not null default 'insurance_case_files',
  object_path text not null unique,
  file_name text not null,
  mime_type text not null default 'application/octet-stream',
  byte_size bigint check (byte_size is null or byte_size >= 0),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid()
);

create index if not exists insurance_case_file_attachments_record_idx
  on public.insurance_case_file_attachments (record_id, created_at desc);
create index if not exists insurance_case_file_attachments_claim_idx
  on public.insurance_case_file_attachments (claim_id, created_at desc);

create table if not exists public.insurance_case_file_audit (
  id bigint generated always as identity primary key,
  claim_id text not null references public.claims(id) on delete cascade,
  record_id uuid,
  entity_type text not null check (entity_type in ('record', 'attachment')),
  action text not null check (action in ('insert', 'update', 'delete')),
  changed_fields jsonb not null default '{}'::jsonb,
  old_data jsonb,
  new_data jsonb,
  actor_user_id uuid not null,
  occurred_at timestamptz not null default now()
);

create index if not exists insurance_case_file_audit_claim_idx
  on public.insurance_case_file_audit (claim_id, occurred_at desc);
create index if not exists insurance_case_file_audit_record_idx
  on public.insurance_case_file_audit (record_id, occurred_at desc);

create or replace function public.is_claim_participant(p_claim_id text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.claim_participants cp
    where cp.claim_id = p_claim_id
      and cp.user_id::text = auth.uid()::text
  );
$$;

create or replace function public.is_claim_insurance_editor(p_claim_id text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.profiles p
      where p.id::text = auth.uid()::text
        and lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
    )
    and exists (
      select 1
      from public.claim_participants cp
      where cp.claim_id = p_claim_id
        and cp.user_id::text = auth.uid()::text
        and lower(coalesce(cp.role, '')) in ('insurance', 'assicurazione')
    );
$$;

revoke all on function public.is_claim_participant(text) from public;
revoke all on function public.is_claim_insurance_editor(text) from public;
grant execute on function public.is_claim_participant(text) to authenticated;
grant execute on function public.is_claim_insurance_editor(text) to authenticated;

create or replace function public.insurance_case_file_before_write()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_completed integer := 0;
  v_required integer := 0;
begin
  if auth.uid() is null then
    raise exception 'authenticated_insurance_user_required';
  end if;

  if not public.is_claim_insurance_editor(new.claim_id) then
    raise exception 'insurance_claim_participant_required_for_case_file';
  end if;

  new.updated_at := now();
  new.updated_by := auth.uid();
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

drop trigger if exists insurance_case_file_before_write_trg
  on public.insurance_case_file_records;
create trigger insurance_case_file_before_write_trg
before insert or update on public.insurance_case_file_records
for each row execute function public.insurance_case_file_before_write();

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
begin
  v_old := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_new := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_claim_id := case when tg_op = 'DELETE' then old.claim_id else new.claim_id end;
  v_record_id := case
    when tg_table_name = 'insurance_case_file_records' then
      case when tg_op = 'DELETE' then old.id else new.id end
    else
      case when tg_op = 'DELETE' then old.record_id else new.record_id end
  end;
  v_actor_user_id := coalesce(
    auth.uid(),
    case
      when tg_table_name = 'insurance_case_file_records' then
        case when tg_op = 'DELETE' then old.updated_by else new.updated_by end
      else
        case when tg_op = 'DELETE' then old.created_by else new.created_by end
    end
  );

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
    case
      when tg_table_name = 'insurance_case_file_records' then 'record'
      else 'attachment'
    end,
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

drop trigger if exists insurance_case_file_records_audit_trg
  on public.insurance_case_file_records;
create trigger insurance_case_file_records_audit_trg
after insert or update or delete on public.insurance_case_file_records
for each row execute function public.insurance_case_file_audit_write();

drop trigger if exists insurance_case_file_attachments_audit_trg
  on public.insurance_case_file_attachments;
create trigger insurance_case_file_attachments_audit_trg
after insert or update or delete on public.insurance_case_file_attachments
for each row execute function public.insurance_case_file_audit_write();

alter table public.insurance_case_file_records enable row level security;
alter table public.insurance_case_file_attachments enable row level security;
alter table public.insurance_case_file_audit enable row level security;

drop policy if exists insurance_case_file_records_select_participant
  on public.insurance_case_file_records;
create policy insurance_case_file_records_select_participant
on public.insurance_case_file_records
for select to authenticated
using (public.is_claim_participant(claim_id));

drop policy if exists insurance_case_file_records_write_insurance
  on public.insurance_case_file_records;
create policy insurance_case_file_records_write_insurance
on public.insurance_case_file_records
for all to authenticated
using (public.is_claim_insurance_editor(claim_id))
with check (public.is_claim_insurance_editor(claim_id));

drop policy if exists insurance_case_file_attachments_select_participant
  on public.insurance_case_file_attachments;
create policy insurance_case_file_attachments_select_participant
on public.insurance_case_file_attachments
for select to authenticated
using (public.is_claim_participant(claim_id));

drop policy if exists insurance_case_file_attachments_write_insurance
  on public.insurance_case_file_attachments;
create policy insurance_case_file_attachments_write_insurance
on public.insurance_case_file_attachments
for all to authenticated
using (public.is_claim_insurance_editor(claim_id))
with check (public.is_claim_insurance_editor(claim_id));

drop policy if exists insurance_case_file_audit_select_participant
  on public.insurance_case_file_audit;
create policy insurance_case_file_audit_select_participant
on public.insurance_case_file_audit
for select to authenticated
using (public.is_claim_participant(claim_id));

revoke all on public.insurance_case_file_records from anon, authenticated;
revoke all on public.insurance_case_file_attachments from anon, authenticated;
revoke all on public.insurance_case_file_audit from anon, authenticated;
grant select on public.insurance_case_file_records to authenticated;
grant select on public.insurance_case_file_attachments to authenticated;
grant select on public.insurance_case_file_audit to authenticated;

create or replace function public.get_insurance_case_file(p_claim_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
begin
  if not public.is_claim_participant(p_claim_id) then
    raise exception 'claim_participant_required_for_case_file';
  end if;

  select jsonb_build_object(
    'records', coalesce((
      select jsonb_agg(
        to_jsonb(r) || jsonb_build_object(
          'updated_by_name', coalesce(
            nullif(btrim(p.display_name), ''),
            nullif(btrim(p.company_name), ''),
            nullif(btrim(p.email), ''),
            r.updated_by::text
          )
        ) order by r.record_type, r.source_index
      )
      from public.insurance_case_file_records r
      left join public.profiles p on p.id::text = r.updated_by::text
      where r.claim_id = p_claim_id
    ), '[]'::jsonb),
    'attachments', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.created_at desc)
      from public.insurance_case_file_attachments a
      where a.claim_id = p_claim_id
    ), '[]'::jsonb),
    'audit', coalesce((
      select jsonb_agg(
        to_jsonb(x) || jsonb_build_object(
          'actor_name', coalesce(
            nullif(btrim(p.display_name), ''),
            nullif(btrim(p.company_name), ''),
            nullif(btrim(p.email), ''),
            x.actor_user_id::text
          )
        ) order by x.occurred_at desc
      )
      from (
        select a.*
        from public.insurance_case_file_audit a
        where a.claim_id = p_claim_id
        order by a.occurred_at desc
        limit 100
      ) x
      left join public.profiles p on p.id::text = x.actor_user_id::text
    ), '[]'::jsonb),
    'can_edit', public.is_claim_insurance_editor(p_claim_id)
  ) into v_result;

  return v_result;
end;
$$;

create or replace function public.save_insurance_case_file_record(
  p_claim_id text,
  p_record_id uuid,
  p_record_type text,
  p_source_index integer,
  p_data jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_record public.insurance_case_file_records;
begin
  if not public.is_claim_insurance_editor(p_claim_id) then
    raise exception 'insurance_claim_participant_required_for_case_file';
  end if;
  if p_record_type not in ('witness', 'injured', 'emergency_contact') then
    raise exception 'invalid_insurance_case_file_record_type';
  end if;

  insert into public.insurance_case_file_records as r (
    id, claim_id, record_type, source_index,
    first_name, last_name, birth_date, gender, nationality, spoken_language,
    phone, email, street, postal_code, city, country,
    document_type, document_number, document_expiry,
    witness_statement, digital_signature_text,
    injury_severity, body_part, ambulance_attended, hospitalized,
    hospital_name, doctor_name, hospital_case_number,
    relationship, notes
  ) values (
    coalesce(p_record_id, extensions.gen_random_uuid()),
    p_claim_id,
    p_record_type,
    greatest(coalesce(p_source_index, 0), 0),
    nullif(btrim(p_data ->> 'first_name'), ''),
    nullif(btrim(p_data ->> 'last_name'), ''),
    nullif(p_data ->> 'birth_date', '')::date,
    nullif(btrim(p_data ->> 'gender'), ''),
    nullif(btrim(p_data ->> 'nationality'), ''),
    nullif(btrim(p_data ->> 'spoken_language'), ''),
    nullif(btrim(p_data ->> 'phone'), ''),
    nullif(btrim(p_data ->> 'email'), ''),
    nullif(btrim(p_data ->> 'street'), ''),
    nullif(btrim(p_data ->> 'postal_code'), ''),
    nullif(btrim(p_data ->> 'city'), ''),
    nullif(btrim(p_data ->> 'country'), ''),
    nullif(btrim(p_data ->> 'document_type'), ''),
    nullif(btrim(p_data ->> 'document_number'), ''),
    nullif(p_data ->> 'document_expiry', '')::date,
    nullif(btrim(p_data ->> 'witness_statement'), ''),
    nullif(btrim(p_data ->> 'digital_signature_text'), ''),
    nullif(btrim(p_data ->> 'injury_severity'), ''),
    nullif(btrim(p_data ->> 'body_part'), ''),
    case when p_data ? 'ambulance_attended'
      then (p_data ->> 'ambulance_attended')::boolean end,
    case when p_data ? 'hospitalized'
      then (p_data ->> 'hospitalized')::boolean end,
    nullif(btrim(p_data ->> 'hospital_name'), ''),
    nullif(btrim(p_data ->> 'doctor_name'), ''),
    nullif(btrim(p_data ->> 'hospital_case_number'), ''),
    nullif(btrim(p_data ->> 'relationship'), ''),
    nullif(btrim(p_data ->> 'notes'), '')
  )
  on conflict (claim_id, record_type, source_index) do update set
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    birth_date = excluded.birth_date,
    gender = excluded.gender,
    nationality = excluded.nationality,
    spoken_language = excluded.spoken_language,
    phone = excluded.phone,
    email = excluded.email,
    street = excluded.street,
    postal_code = excluded.postal_code,
    city = excluded.city,
    country = excluded.country,
    document_type = excluded.document_type,
    document_number = excluded.document_number,
    document_expiry = excluded.document_expiry,
    witness_statement = excluded.witness_statement,
    digital_signature_text = excluded.digital_signature_text,
    injury_severity = excluded.injury_severity,
    body_part = excluded.body_part,
    ambulance_attended = excluded.ambulance_attended,
    hospitalized = excluded.hospitalized,
    hospital_name = excluded.hospital_name,
    doctor_name = excluded.doctor_name,
    hospital_case_number = excluded.hospital_case_number,
    relationship = excluded.relationship,
    notes = excluded.notes
  returning r.* into v_record;

  return to_jsonb(v_record);
end;
$$;

create or replace function public.register_insurance_case_file_attachment(
  p_claim_id text,
  p_record_id uuid,
  p_category text,
  p_object_path text,
  p_file_name text,
  p_mime_type text,
  p_byte_size bigint
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
  if not exists (
    select 1 from public.insurance_case_file_records r
    where r.id = p_record_id and r.claim_id = p_claim_id
  ) then
    raise exception 'insurance_case_file_record_not_found';
  end if;
  if p_object_path not like p_claim_id || '/%' then
    raise exception 'invalid_insurance_case_file_object_path';
  end if;

  insert into public.insurance_case_file_attachments (
    claim_id, record_id, category, object_path,
    file_name, mime_type, byte_size
  ) values (
    p_claim_id, p_record_id, p_category, p_object_path,
    p_file_name, coalesce(nullif(p_mime_type, ''), 'application/octet-stream'),
    p_byte_size
  ) returning * into v_attachment;
  return to_jsonb(v_attachment);
end;
$$;

revoke all on function public.get_insurance_case_file(text) from public;
revoke all on function public.save_insurance_case_file_record(
  text, uuid, text, integer, jsonb
) from public;
revoke all on function public.register_insurance_case_file_attachment(
  text, uuid, text, text, text, text, bigint
) from public;
grant execute on function public.get_insurance_case_file(text) to authenticated;
grant execute on function public.save_insurance_case_file_record(
  text, uuid, text, integer, jsonb
) to authenticated;
grant execute on function public.register_insurance_case_file_attachment(
  text, uuid, text, text, text, text, bigint
) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit)
values ('insurance_case_files', 'insurance_case_files', false, 20971520)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit;

drop policy if exists insurance_case_files_read_participant on storage.objects;
create policy insurance_case_files_read_participant
on storage.objects for select to authenticated
using (
  bucket_id = 'insurance_case_files'
  and public.is_claim_participant((storage.foldername(name))[1])
);

drop policy if exists insurance_case_files_insert_insurance on storage.objects;
create policy insurance_case_files_insert_insurance
on storage.objects for insert to authenticated
with check (
  bucket_id = 'insurance_case_files'
  and public.is_claim_insurance_editor((storage.foldername(name))[1])
);

drop policy if exists insurance_case_files_update_insurance on storage.objects;
create policy insurance_case_files_update_insurance
on storage.objects for update to authenticated
using (
  bucket_id = 'insurance_case_files'
  and public.is_claim_insurance_editor((storage.foldername(name))[1])
)
with check (
  bucket_id = 'insurance_case_files'
  and public.is_claim_insurance_editor((storage.foldername(name))[1])
);

drop policy if exists insurance_case_files_delete_insurance on storage.objects;
create policy insurance_case_files_delete_insurance
on storage.objects for delete to authenticated
using (
  bucket_id = 'insurance_case_files'
  and public.is_claim_insurance_editor((storage.foldername(name))[1])
);

comment on table public.insurance_case_file_records is
  'Normalized insurance-only investigation dossier for witnesses, injured persons and emergency contacts.';
comment on table public.insurance_case_file_attachments is
  'Private metadata for documents stored in the insurance_case_files bucket.';
comment on table public.insurance_case_file_audit is
  'Immutable audit trail generated automatically for insurance dossier changes.';

commit;
