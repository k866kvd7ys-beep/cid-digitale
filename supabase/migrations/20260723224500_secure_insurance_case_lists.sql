begin;

create or replace function public.is_current_user_insurance()
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
    );
$$;

create or replace function public.current_insurance_user_can_access_claim(
  p_claim_id text,
  p_insurance_user_id text,
  p_insurer_org_id text,
  p_suggested_insurer_org_id text
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  with actor as (
    select
      p.org_id::text as org_id,
      p.insurance_id::text as insurance_id
    from public.profiles p
    where p.id::text = auth.uid()::text
      and lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
    limit 1
  )
  select auth.uid() is not null
    and exists (
      select 1
      from actor
      where p_insurance_user_id = auth.uid()::text
        or (
          actor.org_id is not null
          and actor.org_id in (
            p_insurer_org_id,
            p_suggested_insurer_org_id
          )
        )
        or (
          actor.insurance_id is not null
          and actor.insurance_id in (
            p_insurer_org_id,
            p_suggested_insurer_org_id
          )
        )
        or exists (
          select 1
          from public.claim_participants cp
          where cp.claim_id::text = p_claim_id
            and cp.user_id::text = auth.uid()::text
            and lower(coalesce(cp.role, '')) in (
              'insurance',
              'assicurazione'
            )
        )
    );
$$;

create or replace function public.get_insurance_claims_for_current_user(
  p_scope text default 'all',
  p_limit integer default 1000
)
returns setof public.claims
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_profile record;
  v_scope text := lower(btrim(coalesce(p_scope, 'all')));
  v_limit integer := least(greatest(coalesce(p_limit, 1000), 1), 1000);
begin
  if auth.uid() is null then
    raise exception 'authenticated_insurance_user_required';
  end if;

  select
    p.id,
    p.org_id,
    p.insurance_id
  into v_profile
  from public.profiles p
  where p.id::text = auth.uid()::text
    and lower(coalesce(p.role, '')) in ('insurance', 'assicurazione')
  limit 1;

  if not found then
    raise exception 'insurance_profile_required_for_case_list';
  end if;

  if v_scope not in ('all', 'open', 'closed') then
    raise exception 'invalid_insurance_case_scope:%', v_scope;
  end if;

  return query
  select c.*
  from public.claims c
  where public.current_insurance_user_can_access_claim(
    c.id::text,
    c.insurance_user_id::text,
    c.insurer_org_id::text,
    c.suggested_insurer_org_id::text
  )
  and case v_scope
    when 'closed' then lower(btrim(coalesce(c.status, ''))) in (
      'geschlossen',
      'closed',
      'abgeschlossen',
      'chiusa',
      'fermé',
      'ferme',
      'clôturé',
      'cloture'
    )
    when 'open' then lower(btrim(coalesce(c.status, ''))) not in (
      'geschlossen',
      'closed',
      'abgeschlossen',
      'chiusa',
      'fermé',
      'ferme',
      'clôturé',
      'cloture'
    )
    else true
  end
  order by c.created_at desc
  limit v_limit;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'claims'
      and c.relrowsecurity
  ) then
    raise exception
      'claims_rls_must_be_enabled_before_insurance_tenant_policy';
  end if;
end;
$$;

drop policy if exists "claims_insurance_tenant_select_restrictive"
  on public.claims;

create policy "claims_insurance_tenant_select_restrictive"
on public.claims
as restrictive
for select
to authenticated
using (
  not public.is_current_user_insurance()
  or public.current_insurance_user_can_access_claim(
    id::text,
    insurance_user_id::text,
    insurer_org_id::text,
    suggested_insurer_org_id::text
  )
);

revoke all on function public.is_current_user_insurance() from public;
revoke all on function public.is_current_user_insurance() from anon;
grant execute on function public.is_current_user_insurance()
  to authenticated;

revoke all on function public.current_insurance_user_can_access_claim(
  text,
  text,
  text,
  text
) from public;
revoke all on function public.current_insurance_user_can_access_claim(
  text,
  text,
  text,
  text
) from anon;
grant execute on function public.current_insurance_user_can_access_claim(
  text,
  text,
  text,
  text
) to authenticated;

revoke all on function public.get_insurance_claims_for_current_user(
  text,
  integer
) from public;
revoke all on function public.get_insurance_claims_for_current_user(
  text,
  integer
) from anon;
grant execute on function public.get_insurance_claims_for_current_user(
  text,
  integer
) to authenticated;

comment on function public.get_insurance_claims_for_current_user(text, integer)
is 'Fail-closed tenant-scoped insurance case list for dashboard, open cases, and closed cases.';

commit;
