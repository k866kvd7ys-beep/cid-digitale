begin;

create or replace function public.resolve_organization_id_from_insurer(
  p_insurance_id text,
  p_display_name text default null,
  p_company_name text default null
)
returns uuid
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_term text;
  v_column text;
  v_result uuid;
begin
  if coalesce(btrim(p_insurance_id), '') = ''
      and coalesce(btrim(p_display_name), '') = ''
      and coalesce(btrim(p_company_name), '') = '' then
    return null;
  end if;

  for v_term in
    select distinct term
    from (
      select unnest(
        array[
          p_insurance_id,
          p_display_name,
          p_company_name
        ]
      ) as term
      union all
      select a.alias
      from public.insurance_directory_aliases a
      where a.insurance_id = p_insurance_id
    ) terms
    where coalesce(btrim(term), '') <> ''
  loop
    for v_column in
      select c.column_name
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'organizations'
        and c.column_name in (
          'insurance_id',
          'slug',
          'code',
          'name',
          'display_name',
          'company_name',
          'title'
        )
      order by case c.column_name
        when 'insurance_id' then 1
        when 'slug' then 2
        when 'code' then 3
        when 'name' then 4
        when 'display_name' then 5
        when 'company_name' then 6
        when 'title' then 7
        else 99
      end
    loop
      execute format(
        'select id::uuid
         from public.organizations
         where public.normalize_insurance_key(coalesce(%I::text, '''')) = $1
         limit 1',
        v_column
      )
      into v_result
      using public.normalize_insurance_key(v_term);

      if v_result is not null then
        return v_result;
      end if;
    end loop;
  end loop;

  return null;
end;
$$;

grant execute on function public.resolve_organization_id_from_insurer(text, text, text) to authenticated;

comment on function public.resolve_organization_id_from_insurer(text, text, text)
is 'Resolves a Swiss insurer to a real public.organizations.id using directory aliases and organization metadata.';

with resolved_directory as (
  select
    d.insurance_id,
    public.resolve_organization_id_from_insurer(
      d.insurance_id,
      d.display_name,
      d.company_name
    ) as resolved_org_id
  from public.insurance_directory d
)
update public.insurance_directory d
set
  org_id = r.resolved_org_id,
  updated_at = timezone('utc', now())
from resolved_directory r
where d.insurance_id = r.insurance_id
  and r.resolved_org_id is not null
  and d.org_id is distinct from r.resolved_org_id;

with resolved_profiles as (
  select distinct on (p.id)
    p.id,
    public.resolve_organization_id_from_insurer(
      d.insurance_id,
      d.display_name,
      d.company_name
    ) as resolved_org_id
  from public.profiles p
  join public.insurance_directory d
    on exists (
      select 1
      from public.insurance_directory_aliases a
      where a.insurance_id = d.insurance_id
        and a.normalized_alias in (
          public.normalize_insurance_key(p.company_name),
          public.normalize_insurance_key(p.display_name),
          public.normalize_insurance_key(split_part(lower(coalesce(p.email, '')), '@', 1)),
          public.normalize_insurance_key(split_part(split_part(lower(coalesce(p.email, '')), '@', 2), '.', 1))
        )
    )
  where lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
  order by p.id, d.insurance_id
)
update public.profiles p
set
  org_id = r.resolved_org_id,
  updated_at = timezone('utc', now())
from resolved_profiles r
where p.id = r.id
  and r.resolved_org_id is not null
  and p.org_id is distinct from r.resolved_org_id;

create or replace function public.resolve_insurance_directory(
  p_raw_name text
)
returns table (
  insurance_id text,
  org_id uuid,
  display_name text,
  company_name text,
  active boolean
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  with matched as (
    select
      d.insurance_id,
      coalesce(
        (
          select o.id::uuid
          from public.organizations o
          where o.id = d.org_id
          limit 1
        ),
        public.resolve_organization_id_from_insurer(
          d.insurance_id,
          d.display_name,
          d.company_name
        )
      ) as resolved_org_id,
      d.display_name,
      d.company_name,
      d.active
    from public.insurance_directory_aliases a
    join public.insurance_directory d
      on d.insurance_id = a.insurance_id
    where a.normalized_alias = public.normalize_insurance_key(p_raw_name)
      and d.active = true
    order by a.is_primary desc, d.insurance_id
    limit 1
  )
  select
    insurance_id,
    resolved_org_id as org_id,
    display_name,
    company_name,
    active
  from matched;
$$;

grant execute on function public.resolve_insurance_directory(text) to authenticated;

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

commit;
