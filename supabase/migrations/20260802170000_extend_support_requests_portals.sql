begin;
alter table public.support_requests
  add column if not exists source_portal text not null default 'client',
  add column if not exists workshop_id uuid,
  add column if not exists insurance_id uuid,
  add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.support_requests
  drop constraint if exists support_requests_request_type_check,
  add constraint support_requests_request_type_check
    check (
      request_type in (
        'problem',
        'question',
        'suggestion',
        'technical_problem',
        'access_problem',
        'claim_problem',
        'document_problem',
        'general_question',
        'other'
      )
    ),
  add constraint support_requests_source_portal_check
    check (source_portal in ('client', 'workshop', 'insurance')),
  add constraint support_requests_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),
  add constraint support_requests_portal_tenant_check
    check (
      (source_portal = 'client' and workshop_id is null and insurance_id is null)
      or
      (source_portal = 'workshop' and workshop_id is not null and insurance_id is null)
      or
      (source_portal = 'insurance' and workshop_id is null and insurance_id is not null)
    );
create index if not exists support_requests_workshop_created_at_idx
  on public.support_requests (workshop_id, created_at desc)
  where source_portal = 'workshop';
create index if not exists support_requests_insurance_created_at_idx
  on public.support_requests (insurance_id, created_at desc)
  where source_portal = 'insurance';
drop policy if exists support_requests_insert_own
  on public.support_requests;
create policy support_requests_insert_own
on public.support_requests
for insert
to authenticated
with check (
  auth.uid() = created_by
  and status = 'open'
  and notified_at is null
  and (
    (
      source_portal = 'client'
      and workshop_id is null
      and insurance_id is null
    )
    or
    (
      source_portal = 'workshop'
      and insurance_id is null
      and exists (
        select 1
        from public.profiles as profile
        where profile.id = auth.uid()
          and lower(btrim(profile.role)) in ('workshop', 'officina')
          and profile.workshop_id = support_requests.workshop_id
      )
    )
    or
    (
      source_portal = 'insurance'
      and workshop_id is null
      and exists (
        select 1
        from public.profiles as profile
        where profile.id = auth.uid()
          and lower(btrim(profile.role)) in ('insurance', 'assicurazione')
          and profile.insurance_id = support_requests.insurance_id
      )
    )
  )
);
comment on column public.support_requests.source_portal is
  'Authenticated source portal: client, workshop, or insurance.';
comment on column public.support_requests.workshop_id is
  'Workshop tenant UUID, verified against the authenticated profile by RLS.';
comment on column public.support_requests.insurance_id is
  'Insurance tenant UUID, verified against the authenticated profile by RLS.';
comment on column public.support_requests.metadata is
  'Non-sensitive technical context such as locale, page URL, and app build.';
commit;
