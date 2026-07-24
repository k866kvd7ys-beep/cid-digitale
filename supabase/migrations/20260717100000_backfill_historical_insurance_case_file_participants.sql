begin;

do $$
declare
  v_claim record;
  v_payload jsonb;
  v_liability_value text;
  v_effective_insurer_text text;
  v_target_org_id uuid;
  v_candidate_user_id uuid;
  v_candidate_count integer;
  v_recovered_count integer := 0;
  v_unresolved_count integer := 0;
begin
  for v_claim in
    select
      c.id::text as claim_id,
      c.insurance_user_id,
      c.insurer_org_id,
      c.suggested_insurer_org_id,
      c.suggested_insurer_text,
      c.payload_json
    from public.claims c
    where not exists (
      select 1
      from public.claim_participants cp
      where cp.claim_id = c.id::text
        and lower(coalesce(cp.role, '')) in ('insurance', 'assicurazione')
    )
    order by c.id::text
  loop
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

    v_effective_insurer_text := nullif(
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

    v_target_org_id := coalesce(
      v_claim.insurer_org_id,
      v_claim.suggested_insurer_org_id
    );

    if v_target_org_id is null and v_effective_insurer_text is not null then
      select d.org_id
        into v_target_org_id
      from public.resolve_insurance_directory(v_effective_insurer_text) d
      limit 1;
    end if;

    v_candidate_user_id := null;
    v_candidate_count := 0;

    if v_claim.insurance_user_id is not null then
      select
        count(*)::integer,
        (array_agg(p.id order by p.id))[1]
        into v_candidate_count, v_candidate_user_id
      from public.profiles p
      where p.id::text = v_claim.insurance_user_id::text
        and lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
        and (
          v_target_org_id is null
          or p.org_id = v_target_org_id
          or p.insurance_id = v_target_org_id
        );
    elsif v_target_org_id is not null then
      select
        count(*)::integer,
        (array_agg(p.id order by p.id))[1]
        into v_candidate_count, v_candidate_user_id
      from public.profiles p
      where lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
        and (
          p.org_id = v_target_org_id
          or p.insurance_id = v_target_org_id
        );
    end if;

    if v_candidate_count = 1 and v_candidate_user_id is not null then
      insert into public.claim_participants (
        claim_id,
        user_id,
        role
      )
      select
        v_claim.claim_id,
        v_candidate_user_id,
        'insurance'
      where not exists (
        select 1
        from public.claim_participants cp
        where cp.claim_id = v_claim.claim_id
          and cp.user_id::text = v_candidate_user_id::text
          and lower(coalesce(cp.role, '')) in ('insurance', 'assicurazione')
      );

      if found then
        v_recovered_count := v_recovered_count + 1;
      end if;
    else
      v_unresolved_count := v_unresolved_count + 1;
      raise notice
        'Fascicolo Assicurazione: pratica % non risolta; insurance_user_id=%, target_org_id=%, insurer_text=%, candidate_count=%',
        v_claim.claim_id,
        coalesce(v_claim.insurance_user_id::text, '<null>'),
        coalesce(v_target_org_id::text, '<null>'),
        coalesce(v_effective_insurer_text, '<null>'),
        v_candidate_count;
    end if;
  end loop;

  raise notice
    'Fascicolo Assicurazione storico: pratiche recuperate=%, pratiche non risolvibili=%',
    v_recovered_count,
    v_unresolved_count;
end;
$$;

commit;
