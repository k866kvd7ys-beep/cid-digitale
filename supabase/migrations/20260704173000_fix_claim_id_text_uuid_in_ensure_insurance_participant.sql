begin;

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

comment on function public.ensure_claim_insurance_participant(uuid, text)
is 'Fixes claims.id text vs uuid comparisons by casting claim id predicates to text.';

commit;
