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
  v_liability_value text;
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
  v_liability_value := regexp_replace(
    lower(
      coalesce(
        v_payload ->> 'colpevole',
        v_payload ->> 'guilty_party',
        ''
      )
    ),
    '[^a-z0-9]+',
    '',
    'g'
  );

  v_effective_text := nullif(
    btrim(
      coalesce(
        case
          when v_liability_value in (
            'b',
            'conducenteb',
            'driverb',
            'fahrerb',
            'conducteurb',
            'counterparty',
            'gegenpartei',
            'seconddriver',
            'secondofahrer',
            'secondoconducente'
          ) then coalesce(
            v_payload ->> 'assicurazioneB',
            v_payload -> 'conducenteB' ->> 'assicurazione',
            v_payload -> 'conducenteB' ->> 'insurance',
            v_payload -> 'conducenteB' ->> 'company',
            v_payload -> 'conducenteB' ->> 'provider',
            v_payload -> 'driverB' ->> 'assicurazione',
            v_payload -> 'driverB' ->> 'insurance',
            v_payload -> 'driverB' ->> 'company',
            v_payload -> 'driverB' ->> 'provider',
            v_payload -> 'second_driver' ->> 'assicurazione',
            v_payload -> 'second_driver' ->> 'insurance'
          )
          else null
        end,
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
is 'Routes liability-B claims to the insurance company of driver B before creating the insurance participant.';

drop function if exists public.update_claim_status_for_insurance(uuid, text);

create function public.update_claim_status_for_insurance(
  p_claim_id uuid,
  p_new_status text
)
returns table (
  claim_id text,
  previous_status text,
  status text,
  updated boolean
)
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_actor_profile record;
  v_claim record;
  v_normalized_status text;
  v_payload jsonb;
begin
  if auth.uid() is null then
    raise exception 'authenticated_insurance_user_required';
  end if;

  select
    p.id,
    p.role,
    p.org_id,
    p.insurance_id
  into v_actor_profile
  from public.profiles p
  where p.id::text = auth.uid()::text
    and lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
  limit 1;

  if not found then
    raise exception 'insurance_profile_required_for_status_update';
  end if;

  v_normalized_status := lower(btrim(coalesce(p_new_status, '')));
  if v_normalized_status not in (
    'warten_auf_freigabe',
    'freigegeben',
    'kein_freigabe',
    'geschlossen'
  ) then
    raise exception 'invalid_claim_status:%', p_new_status;
  end if;

  select
    c.id::text as claim_id,
    c.status,
    c.payload_json
  into v_claim
  from public.claims c
  where c.id::text = p_claim_id::text;

  if not found then
    raise exception 'claim_not_found:%', p_claim_id;
  end if;

  if not exists (
    select 1
    from public.claim_participants cp
    where cp.claim_id::text = p_claim_id::text
      and cp.user_id::text = auth.uid()::text
      and cp.role = 'insurance'
  ) then
    raise exception 'insurance_claim_participant_required_for_status_update';
  end if;

  v_payload := coalesce(v_claim.payload_json::jsonb, '{}'::jsonb) ||
    jsonb_build_object('status', v_normalized_status);

  update public.claims c
  set
    status = v_normalized_status,
    payload_json = v_payload
  where c.id::text = p_claim_id::text;

  if coalesce(v_claim.status, '') <> v_normalized_status then
    insert into public.claim_events (
      claim_id,
      type,
      payload,
      actor_user_id
    )
    values (
      v_claim.claim_id,
      'status_changed',
      jsonb_build_object(
        'from', coalesce(v_claim.status, ''),
        'to', v_normalized_status,
        'actor_role', 'insurance'
      ),
      auth.uid()
    );
  end if;

  return query
  select
    v_claim.claim_id,
    nullif(v_claim.status, ''),
    v_normalized_status,
    true;
end;
$$;

revoke all on function public.update_claim_status_for_insurance(uuid, text) from public;
grant execute on function public.update_claim_status_for_insurance(uuid, text) to authenticated;

comment on function public.update_claim_status_for_insurance(uuid, text)
is 'Secure status update RPC for insurance users assigned to the claim via claim_participants.';

commit;
