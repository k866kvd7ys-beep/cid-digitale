begin;

drop policy if exists "claim_participants_insert_routed_insurance_auth"
  on public.claim_participants;

create policy "claim_participants_insert_routed_insurance_auth"
on public.claim_participants
for insert
to authenticated
with check (
  role = 'insurance'
  and exists (
    select 1
    from public.claims c
    join public.profiles p
      on coalesce(p.id::text, '') = coalesce(claim_participants.user_id::text, '')
    where coalesce(c.id::text, '') = coalesce(claim_participants.claim_id::text, '')
      and lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
      and (
        coalesce(c.insurance_user_id::text, '') = coalesce(claim_participants.user_id::text, '')
        or (
          coalesce(c.insurer_org_id::text, '') <> ''
          and coalesce(p.org_id::text, '') = coalesce(c.insurer_org_id::text, '')
        )
        or (
          coalesce(c.suggested_insurer_org_id::text, '') <> ''
          and coalesce(p.org_id::text, '') = coalesce(c.suggested_insurer_org_id::text, '')
        )
      )
      and (
        coalesce(c.workshop_user_id::text, '') = coalesce(auth.uid()::text, '')
        or coalesce(c.created_by::text, '') = coalesce(auth.uid()::text, '')
        or exists (
          select 1
          from public.claim_participants cpw
          where coalesce(cpw.claim_id::text, '') = coalesce(c.id::text, '')
            and coalesce(cpw.user_id::text, '') = coalesce(auth.uid()::text, '')
            and cpw.role in ('workshop', 'officina')
        )
      )
  )
);

create or replace function public.resolve_insurance_profile_users(
  p_raw_name text
)
returns table (
  profile_id uuid,
  insurance_id text,
  org_id uuid,
  display_name text,
  company_name text,
  email text
)
language plpgsql
stable
security definer
set search_path = public, extensions, auth
as $$
declare
  resolved record;
begin
  select *
    into resolved
  from public.resolve_insurance_directory(p_raw_name);

  if not found then
    raise exception
      'Assicurazione non registrata nel sistema. Aggiungerla alla directory assicurazioni.';
  end if;

  return query
  with insurer_aliases as (
    select a.normalized_alias
    from public.insurance_directory_aliases a
    where a.insurance_id = resolved.insurance_id
    union
    select public.normalize_insurance_key(resolved.insurance_id)
    union
    select public.normalize_insurance_key(resolved.display_name)
    union
    select public.normalize_insurance_key(resolved.company_name)
  ),
  matched_profiles as (
    select
      p.id::uuid as profile_id,
      resolved.insurance_id as resolved_insurance_id,
      resolved.org_id as resolved_org_id,
      coalesce(nullif(p.display_name, ''), resolved.display_name) as resolved_display_name,
      coalesce(nullif(p.company_name, ''), resolved.company_name) as resolved_company_name,
      p.email,
      p.updated_at,
      case
        when resolved.org_id is not null
             and coalesce(p.org_id::text, '') = resolved.org_id::text
          then 0
        when public.normalize_insurance_key(coalesce(p.insurance_id::text, '')) =
             public.normalize_insurance_key(resolved.insurance_id)
          then 1
        else 2
      end as match_rank
    from public.profiles p
    where lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
      and (
        (
          resolved.org_id is not null
          and coalesce(p.org_id::text, '') = resolved.org_id::text
        )
        or public.normalize_insurance_key(coalesce(p.insurance_id::text, '')) =
            public.normalize_insurance_key(resolved.insurance_id)
        or exists (
          select 1
          from insurer_aliases a
          where a.normalized_alias in (
            public.normalize_insurance_key(p.company_name),
            public.normalize_insurance_key(p.display_name),
            public.normalize_insurance_key(split_part(lower(coalesce(p.email, '')), '@', 1)),
            public.normalize_insurance_key(split_part(split_part(lower(coalesce(p.email, '')), '@', 2), '.', 1))
          )
        )
      )
  )
  select
    mp.profile_id,
    mp.resolved_insurance_id,
    mp.resolved_org_id,
    mp.resolved_display_name,
    mp.resolved_company_name,
    mp.email
  from matched_profiles mp
  order by
    mp.match_rank,
    mp.updated_at desc nulls last,
    mp.profile_id;

  if not found then
    raise exception
      'Profilo assicurazione non collegato. Creare o collegare prima l''utente Auth.';
  end if;
end;
$$;

grant execute on function public.resolve_insurance_profile_users(text) to authenticated;

create or replace function public.ensure_claim_insurance_participant(
  p_claim_id uuid,
  p_insurer_text text default null
)
returns table (
  claim_id uuid,
  insurance_user_id uuid,
  org_id uuid,
  inserted boolean,
  participant_exists boolean,
  resolved_insurer_text text
)
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_claim record;
  v_payload jsonb;
  v_effective_text text;
  v_directory record;
  v_profile record;
  v_exists boolean;
  v_payload_patch jsonb;
begin
  select
    c.id,
    c.insurance_user_id,
    c.insurer_org_id,
    c.suggested_insurer_org_id,
    c.suggested_insurer_text,
    c.payload_json
  into v_claim
  from public.claims c
  where c.id::text = p_claim_id::text;

  if not found then
    raise exception 'Claim non trovata: %', p_claim_id;
  end if;

  v_payload := coalesce(v_claim.payload_json::jsonb, '{}'::jsonb);

  v_effective_text := nullif(
    btrim(
      coalesce(
        p_insurer_text,
        v_claim.suggested_insurer_text,
        v_payload ->> 'suggested_insurer_text',
        v_payload ->> 'insurer_name',
        v_payload -> 'insurance' ->> 'insurance',
        v_payload -> 'insurance' ->> 'company',
        v_payload -> 'insurance' ->> 'name',
        v_payload -> 'insurance' ->> 'provider',
        v_payload -> 'manualCase' -> 'insurance' ->> 'insurance',
        v_payload -> 'manualCase' -> 'insurance' ->> 'company',
        v_payload -> 'manualCase' -> 'insurance' ->> 'name',
        v_payload -> 'manualCase' -> 'insurance' ->> 'provider'
      )
    ),
    ''
  );

  if v_effective_text is null then
    raise exception
      'Assicurazione mancante nella pratica. Selezionare una compagnia prima dell invio.';
  end if;

  select *
    into v_directory
  from public.resolve_insurance_directory(v_effective_text);

  if not found then
    raise exception
      'Assicurazione non registrata nel sistema. Aggiungerla alla directory assicurazioni.';
  end if;

  select *
    into v_profile
  from public.resolve_insurance_profile_users(v_effective_text)
  limit 1;

  if not found then
    raise exception
      'Profilo assicurazione non collegato. Creare o collegare prima l''utente Auth.';
  end if;

  v_payload_patch := jsonb_build_object(
    'suggested_insurer_text', coalesce(v_directory.display_name, v_effective_text),
    'insurance_user_id', v_profile.profile_id::text
  );

  if v_directory.org_id is not null then
    v_payload_patch := v_payload_patch || jsonb_build_object(
      'insurer_org_id', v_directory.org_id::text,
      'suggested_insurer_org_id', v_directory.org_id::text
    );
  end if;

  v_payload := v_payload || v_payload_patch;

  update public.claims c
  set
    insurance_user_id = v_profile.profile_id,
    insurer_org_id = case
      when v_directory.org_id is not null then v_directory.org_id
      else c.insurer_org_id
    end,
    suggested_insurer_org_id = case
      when v_directory.org_id is not null then v_directory.org_id
      else c.suggested_insurer_org_id
    end,
    suggested_insurer_text = coalesce(v_directory.display_name, v_effective_text),
    suggested_insurer_confidence = 1,
    payload_json = v_payload
  where c.id::text = p_claim_id::text;

  select exists(
    select 1
    from public.claim_participants cp
    where coalesce(cp.claim_id::text, '') = coalesce(p_claim_id::text, '')
      and coalesce(cp.user_id::text, '') = coalesce(v_profile.profile_id::text, '')
      and cp.role = 'insurance'
  )
  into v_exists;

  if not v_exists then
    insert into public.claim_participants (
      claim_id,
      user_id,
      role
    )
    values (
      p_claim_id,
      v_profile.profile_id,
      'insurance'
    );
  end if;

  return query
  select
    p_claim_id,
    v_profile.profile_id,
    v_directory.org_id,
    not v_exists,
    v_exists,
    coalesce(v_directory.display_name, v_effective_text);
end;
$$;

revoke all on function public.ensure_claim_insurance_participant(uuid, text) from public;
grant execute on function public.ensure_claim_insurance_participant(uuid, text) to authenticated;

comment on function public.resolve_insurance_profile_users(text)
is 'Type-safe insurer profile resolver. Matches org_id to org_id and insurance_id to insurance_id.';

comment on function public.ensure_claim_insurance_participant(uuid, text)
is 'Uses the type-safe insurance resolver, updates claims routing fields, and ensures the insurance participant exists.';

commit;
