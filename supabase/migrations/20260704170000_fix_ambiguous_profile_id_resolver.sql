begin;

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

comment on function public.resolve_insurance_profile_users(text)
is 'Fixes ambiguous output-column references by qualifying matched_profiles columns in the resolver.';

commit;
