-- Definitive multi-insurance directory for public.profiles
--
-- Goal:
-- 1. Keep one real profile per insurance login user.
-- 2. Use profiles.id = auth.users.id as the canonical user link.
-- 3. Add stable organization routing fields for claim assignment.
-- 4. Let authenticated workshop/insurance sessions read only:
--    - their own profile
--    - insurance directory profiles
--
-- IMPORTANT BEFORE RUNNING:
-- Replace the placeholder login emails below with the real Auth users
-- you already created in Supabase Authentication.
--
-- If an Auth user does not exist yet:
-- 1. Open Supabase Dashboard -> Authentication -> Users
-- 2. Create the user (or send invite) with the final insurance email
-- 3. Re-run this script after the auth.users row exists

begin;

-- 1) Inspect the current live structure of public.profiles.
do $$
declare
  profile_columns text;
begin
  select string_agg(
           format('%s:%s', column_name, data_type),
           ', '
           order by ordinal_position
         )
    into profile_columns
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles';

  raise notice 'public.profiles columns => %', coalesce(profile_columns, '<missing table>');
end $$;

-- 2) Extend profiles with the fields required for stable multi-insurance routing.
alter table if exists public.profiles
  add column if not exists company_name text;

alter table if exists public.profiles
  add column if not exists org_id uuid;

alter table if exists public.profiles
  add column if not exists display_name text;

alter table if exists public.profiles
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

-- 3) Seed / upsert real insurance directory rows.
--
-- profiles.id is expected to be the Auth user UUID.
-- We do NOT add a redundant user_id column because the current app already
-- resolves profiles by auth.users.id -> profiles.id.
with insurer_seed(insurance_id, org_id, company_name, display_name, login_email) as (
  values
    (
      '11111111-1111-4111-8111-111111111111'::uuid,
      '11111111-1111-4111-8111-111111111111'::uuid,
      'Visana',
      'Visana',
      'claims@visana.example'
    ),
    (
      '22222222-2222-4222-8222-222222222222'::uuid,
      '22222222-2222-4222-8222-222222222222'::uuid,
      'AXA',
      'AXA',
      'claims@axa.example'
    ),
    (
      '33333333-3333-4333-8333-333333333333'::uuid,
      '33333333-3333-4333-8333-333333333333'::uuid,
      'Zurich',
      'Zurich',
      'claims@zurich.example'
    ),
    (
      '44444444-4444-4444-8444-444444444444'::uuid,
      '44444444-4444-4444-8444-444444444444'::uuid,
      'Allianz',
      'Allianz',
      'claims@allianz.example'
    )
),
auth_matches as (
  select
    s.insurance_id,
    s.org_id,
    s.company_name,
    s.display_name,
    lower(s.login_email) as login_email,
    u.id as auth_user_id,
    lower(u.email) as auth_email
  from insurer_seed s
  left join auth.users u
    on lower(u.email) = lower(s.login_email)
)
insert into public.profiles (
  id,
  role,
  insurance_id,
  org_id,
  company_name,
  display_name,
  email,
  updated_at
)
select
  a.auth_user_id,
  'insurance',
  a.insurance_id,
  a.org_id,
  a.company_name,
  a.display_name,
  coalesce(a.auth_email, a.login_email),
  timezone('utc', now())
from auth_matches a
where a.auth_user_id is not null
on conflict (id) do update
set
  role = excluded.role,
  insurance_id = excluded.insurance_id,
  org_id = excluded.org_id,
  company_name = excluded.company_name,
  display_name = excluded.display_name,
  email = excluded.email,
  updated_at = timezone('utc', now());

-- 4) Backfill normalized insurer directory fields for any existing insurance rows.
update public.profiles
set
  insurance_id = case
    when lower(coalesce(company_name, display_name, split_part(email, '@', 1), '')) = 'visana'
      then '11111111-1111-4111-8111-111111111111'::uuid
    when lower(coalesce(company_name, display_name, split_part(email, '@', 1), '')) = 'axa'
      then '22222222-2222-4222-8222-222222222222'::uuid
    when lower(coalesce(company_name, display_name, split_part(email, '@', 1), '')) = 'zurich'
      then '33333333-3333-4333-8333-333333333333'::uuid
    when lower(coalesce(company_name, display_name, split_part(email, '@', 1), '')) = 'allianz'
      then '44444444-4444-4444-8444-444444444444'::uuid
    else insurance_id
  end,
  org_id = case
    when lower(coalesce(company_name, display_name, split_part(email, '@', 1), '')) = 'visana'
      then coalesce(org_id, '11111111-1111-4111-8111-111111111111'::uuid)
    when lower(coalesce(company_name, display_name, split_part(email, '@', 1), '')) = 'axa'
      then coalesce(org_id, '22222222-2222-4222-8222-222222222222'::uuid)
    when lower(coalesce(company_name, display_name, split_part(email, '@', 1), '')) = 'zurich'
      then coalesce(org_id, '33333333-3333-4333-8333-333333333333'::uuid)
    when lower(coalesce(company_name, display_name, split_part(email, '@', 1), '')) = 'allianz'
      then coalesce(org_id, '44444444-4444-4444-8444-444444444444'::uuid)
    else org_id
  end,
  company_name = case
    when insurance_id = '11111111-1111-4111-8111-111111111111'::uuid
      then coalesce(nullif(company_name, ''), 'Visana')
    when insurance_id = '22222222-2222-4222-8222-222222222222'::uuid
      then coalesce(nullif(company_name, ''), 'AXA')
    when insurance_id = '33333333-3333-4333-8333-333333333333'::uuid
      then coalesce(nullif(company_name, ''), 'Zurich')
    when insurance_id = '44444444-4444-4444-8444-444444444444'::uuid
      then coalesce(nullif(company_name, ''), 'Allianz')
    else company_name
  end,
  display_name = coalesce(nullif(display_name, ''), company_name),
  updated_at = timezone('utc', now())
where role in ('insurance', 'assicurazione');

-- 5) Protect against duplicate insurer routing keys.
do $$
declare
  duplicated_insurance_ids int;
  duplicated_org_ids int;
begin
  select count(*)
    into duplicated_insurance_ids
  from (
    select insurance_id
    from public.profiles
    where role in ('insurance', 'assicurazione')
      and insurance_id is not null
    group by insurance_id
    having count(*) > 1
  ) t;

  if duplicated_insurance_ids > 0 then
    raise exception
      'Duplicate insurance profiles found by insurance_id. Clean duplicates before continuing.';
  end if;

  select count(*)
    into duplicated_org_ids
  from (
    select org_id
    from public.profiles
    where role in ('insurance', 'assicurazione')
      and org_id is not null
    group by org_id
    having count(*) > 1
  ) t;

  if duplicated_org_ids > 0 then
    raise exception
      'Duplicate insurance profiles found by org_id. Clean duplicates before continuing.';
  end if;
end $$;

create unique index if not exists profiles_insurance_id_insurance_uidx
  on public.profiles (insurance_id)
  where role in ('insurance', 'assicurazione')
    and insurance_id is not null;

create unique index if not exists profiles_org_id_insurance_uidx
  on public.profiles (org_id)
  where role in ('insurance', 'assicurazione')
    and org_id is not null;

create index if not exists profiles_role_idx
  on public.profiles (role);

-- 6) RLS: allow authenticated users to read their own profile plus
-- the insurance directory used by the routing resolver.
alter table if exists public.profiles enable row level security;

grant select on public.profiles to authenticated;

drop policy if exists "profiles_select_own_or_insurance_directory" on public.profiles;
create policy "profiles_select_own_or_insurance_directory"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  or role in ('insurance', 'assicurazione')
);

commit;

-- ---------------------------------------------------------------------------
-- VERIFICATION QUERIES
-- Run these after the migration in Supabase SQL Editor.
-- ---------------------------------------------------------------------------

-- A) Real profiles structure
-- select column_name, data_type
-- from information_schema.columns
-- where table_schema = 'public'
--   and table_name = 'profiles'
-- order by ordinal_position;

-- B) Insurance directory currently available
-- select id, role, insurance_id, org_id, company_name, display_name, email
-- from public.profiles
-- where role in ('insurance', 'assicurazione')
-- order by insurance_id, email;

-- C) Check which seed emails still have no Auth user
-- with insurer_seed(insurance_id, login_email) as (
--   values
--     ('visana',  'claims@visana.example'),
--     ('axa',     'claims@axa.example'),
--     ('zurich',  'claims@zurich.example'),
--     ('allianz', 'claims@allianz.example')
-- )
-- select s.insurance_id, s.login_email, u.id as auth_user_id
-- from insurer_seed s
-- left join auth.users u
--   on lower(u.email) = lower(s.login_email)
-- order by s.insurance_id;

-- D) Resolver-equivalent lookup for one insurance
-- select id, role, insurance_id, org_id, company_name, email
-- from public.profiles
-- where role in ('insurance', 'assicurazione')
--   and (
--     insurance_id = '11111111-1111-4111-8111-111111111111'::uuid
--     or lower(company_name) = 'visana'
--   );
