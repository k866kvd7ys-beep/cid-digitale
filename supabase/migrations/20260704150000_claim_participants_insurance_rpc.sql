begin;

alter table if exists public.claim_participants enable row level security;

grant insert on public.claim_participants to authenticated;
grant update on public.claims to authenticated;

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
      on p.id::text = claim_participants.user_id::text
    where c.id::text = claim_participants.claim_id::text
      and lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
      and (
        coalesce(c.insurance_user_id::text, '') = claim_participants.user_id::text
        or (
          coalesce(c.insurer_org_id::text, '') <> ''
          and coalesce(p.org_id::text, '') = c.insurer_org_id::text
        )
        or (
          coalesce(c.suggested_insurer_org_id::text, '') <> ''
          and coalesce(p.org_id::text, '') = c.suggested_insurer_org_id::text
        )
      )
      and (
        coalesce(c.workshop_user_id::text, '') = auth.uid()::text
        or coalesce(c.created_by::text, '') = auth.uid()::text
        or exists (
          select 1
          from public.claim_participants cpw
          where cpw.claim_id::text = c.id::text
            and cpw.user_id::text = auth.uid()::text
            and cpw.role in ('workshop', 'officina')
        )
      )
  )
);

drop function if exists public.ensure_claim_insurance_participant(uuid, text);

create function public.ensure_claim_insurance_participant(
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
  where c.id = p_claim_id;

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

  v_payload := v_payload || jsonb_build_object(
    'suggested_insurer_text', coalesce(v_directory.display_name, v_effective_text),
    'insurer_org_id', v_directory.org_id::text,
    'suggested_insurer_org_id', v_directory.org_id::text,
    'insurance_user_id', v_profile.profile_id::text
  );

  update public.claims c
  set
    insurance_user_id = v_profile.profile_id,
    insurer_org_id = v_directory.org_id,
    suggested_insurer_org_id = v_directory.org_id,
    suggested_insurer_text = coalesce(v_directory.display_name, v_effective_text),
    suggested_insurer_confidence = 1,
    payload_json = v_payload
  where c.id = p_claim_id;

  select exists(
    select 1
    from public.claim_participants cp
    where cp.claim_id::text = p_claim_id::text
      and cp.user_id::text = v_profile.profile_id::text
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
is 'Resolves the insurer via directory/profile RPCs, updates claims routing fields, and ensures the insurance participant exists.';

commit;
