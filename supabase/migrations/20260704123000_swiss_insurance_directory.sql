-- Definitive Swiss multi-insurance directory
--
-- Fixes for the failed draft:
-- 1. public.profiles.insurance_id is treated as UUID and never coalesced with ''.
-- 2. Text matching uses only text fields such as company_name, display_name and email.
-- 3. org_id is stored as a stable UUID in both the directory and linked insurance profiles.
-- 4. The script is idempotent and safe to re-run after a partial execution.

begin;

create extension if not exists unaccent with schema extensions;

-- ---------------------------------------------------------------------------
-- 1) Helpers
-- ---------------------------------------------------------------------------
create or replace function public.normalize_insurance_key(input text)
returns text
language sql
immutable
as $$
  select regexp_replace(
           lower(extensions.unaccent(coalesce(input, ''))),
           '[^a-z0-9]+',
           '',
           'g'
         );
$$;

comment on function public.normalize_insurance_key(text)
is 'Normalizes insurer names and aliases for Swiss insurance routing.';

create or replace function public.insurance_org_uuid(p_lookup text)
returns uuid
language sql
immutable
as $$
  select case public.normalize_insurance_key(p_lookup)
    when 'visana' then '11111111-1111-4111-8111-111111111111'::uuid
    when 'orgvisana' then '11111111-1111-4111-8111-111111111111'::uuid
    when 'axa' then '22222222-2222-4222-8222-222222222222'::uuid
    when 'orgaxa' then '22222222-2222-4222-8222-222222222222'::uuid
    when 'zurich' then '33333333-3333-4333-8333-333333333333'::uuid
    when 'orgzurich' then '33333333-3333-4333-8333-333333333333'::uuid
    when 'allianz' then '44444444-4444-4444-8444-444444444444'::uuid
    when 'orgallianz' then '44444444-4444-4444-8444-444444444444'::uuid
    when 'generali' then '55555555-5555-4555-8555-555555555555'::uuid
    when 'orggenerali' then '55555555-5555-4555-8555-555555555555'::uuid
    when 'helvetia' then '66666666-6666-4666-8666-666666666666'::uuid
    when 'orghelvetia' then '66666666-6666-4666-8666-666666666666'::uuid
    when 'mobiliar' then '77777777-7777-4777-8777-777777777777'::uuid
    when 'diemobiliar' then '77777777-7777-4777-8777-777777777777'::uuid
    when 'orgmobiliar' then '77777777-7777-4777-8777-777777777777'::uuid
    when 'baloise' then '88888888-8888-4888-8888-888888888888'::uuid
    when 'basler' then '88888888-8888-4888-8888-888888888888'::uuid
    when 'orgbaloise' then '88888888-8888-4888-8888-888888888888'::uuid
    when 'css' then '99999999-9999-4999-8999-999999999999'::uuid
    when 'orgcss' then '99999999-9999-4999-8999-999999999999'::uuid
    when 'vaudoise' then 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
    when 'orgvaudoise' then 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
    when 'groupemutuel' then 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid
    when 'orggroupemutuel' then 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid
    when 'helsana' then 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'::uuid
    when 'orghelsana' then 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'::uuid
    when 'swica' then 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid
    when 'orgswica' then 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid
    when 'sanitas' then 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid
    when 'orgsanitas' then 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid
    when 'concordia' then 'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid
    when 'orgconcordia' then 'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid
    when 'okk' then '12121212-1212-4212-8212-121212121212'::uuid
    when 'oekk' then '12121212-1212-4212-8212-121212121212'::uuid
    when 'orgoekk' then '12121212-1212-4212-8212-121212121212'::uuid
    when 'sympany' then '13131313-1313-4313-8313-131313131313'::uuid
    when 'orgsympany' then '13131313-1313-4313-8313-131313131313'::uuid
    when 'assura' then '14141414-1414-4414-8414-141414141414'::uuid
    when 'orgassura' then '14141414-1414-4414-8414-141414141414'::uuid
    when 'atupri' then '15151515-1515-4515-8515-151515151515'::uuid
    when 'orgatupri' then '15151515-1515-4515-8515-151515151515'::uuid
    when 'tcs' then '16161616-1616-4616-8616-161616161616'::uuid
    when 'orgtcs' then '16161616-1616-4616-8616-161616161616'::uuid
    when 'smile' then '17171717-1717-4717-8717-171717171717'::uuid
    when 'orgsmile' then '17171717-1717-4717-8717-171717171717'::uuid
    when 'dextra' then '18181818-1818-4818-8818-181818181818'::uuid
    when 'orgdextra' then '18181818-1818-4818-8818-181818181818'::uuid
    when 'cooprechtsschutz' then '19191919-1919-4919-8919-191919191919'::uuid
    when 'orgcooprechtsschutz' then '19191919-1919-4919-8919-191919191919'::uuid
    when 'protekta' then '20202020-2020-4020-8020-202020202020'::uuid
    when 'orgprotekta' then '20202020-2020-4020-8020-202020202020'::uuid
    when 'elvia' then '21212121-2121-4121-8121-212121212121'::uuid
    when 'orgelvia' then '21212121-2121-4121-8121-212121212121'::uuid
    when 'simpego' then '23232323-2323-4232-8232-232323232323'::uuid
    when 'orgsimpego' then '23232323-2323-4232-8232-232323232323'::uuid
    when 'postfinanceversicherung' then '24242424-2424-4242-8242-242424242424'::uuid
    when 'orgpostfinanceversicherung' then '24242424-2424-4242-8242-242424242424'::uuid
    when 'migrosversicherung' then '25252525-2525-4252-8252-252525252525'::uuid
    when 'orgmigrosversicherung' then '25252525-2525-4252-8252-252525252525'::uuid
    when 'hdi' then '26262626-2626-4262-8262-262626262626'::uuid
    when 'orghdi' then '26262626-2626-4262-8262-262626262626'::uuid
    when 'chubb' then '27272727-2727-4272-8272-272727272727'::uuid
    when 'orgchubb' then '27272727-2727-4272-8272-272727272727'::uuid
    when 'liberty' then '28282828-2828-4282-8282-282828282828'::uuid
    when 'orgliberty' then '28282828-2828-4282-8282-282828282828'::uuid
    when 'aig' then '29292929-2929-4292-8292-292929292929'::uuid
    when 'orgaig' then '29292929-2929-4292-8292-292929292929'::uuid
    else null
  end;
$$;

comment on function public.insurance_org_uuid(text)
is 'Maps a canonical insurance code or legacy org_* label to the stable insurer org UUID.';

do $$
declare
  profiles_insurance_type text;
  profiles_org_type text;
begin
  select data_type
    into profiles_insurance_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles'
    and column_name = 'insurance_id';

  if profiles_insurance_type is distinct from 'uuid' then
    raise exception
      'public.profiles.insurance_id must be uuid. Found: %',
      coalesce(profiles_insurance_type, '<missing>');
  end if;

  alter table public.profiles
    add column if not exists company_name text;

  alter table public.profiles
    add column if not exists display_name text;

  alter table public.profiles
    add column if not exists updated_at timestamptz;

  select data_type
    into profiles_org_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles'
    and column_name = 'org_id';

  if profiles_org_type is null then
    execute 'alter table public.profiles add column org_id uuid';
  elsif profiles_org_type <> 'uuid' then
    execute $sql$
      alter table public.profiles
      alter column org_id type uuid
      using (
        case
          when org_id is null then null
          when btrim(org_id::text) = '' then coalesce(
            public.insurance_org_uuid(company_name),
            public.insurance_org_uuid(display_name)
          )
          when org_id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
            then org_id::text::uuid
          else coalesce(
            public.insurance_org_uuid(org_id::text),
            public.insurance_org_uuid(company_name),
            public.insurance_org_uuid(display_name)
          )
        end
      )
    $sql$;
  end if;
end $$;

update public.profiles
set updated_at = timezone('utc', now())
where updated_at is null;

alter table public.profiles
  alter column updated_at set default timezone('utc', now());

alter table public.profiles
  alter column updated_at set not null;

create index if not exists profiles_role_idx
  on public.profiles (role);

create index if not exists profiles_org_id_role_idx
  on public.profiles (org_id, role);

create index if not exists profiles_insurance_id_role_idx
  on public.profiles (insurance_id, role);

-- ---------------------------------------------------------------------------
-- 2) Directory master tables
-- ---------------------------------------------------------------------------
create table if not exists public.insurance_directory (
  insurance_id text primary key,
  org_id uuid not null unique,
  display_name text not null,
  company_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (btrim(insurance_id) <> ''),
  check (btrim(display_name) <> ''),
  check (btrim(company_name) <> '')
);

alter table if exists public.insurance_directory
  add column if not exists active boolean not null default true;

alter table if exists public.insurance_directory
  add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.insurance_directory
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

do $$
declare
  directory_org_type text;
begin
  select data_type
    into directory_org_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'insurance_directory'
    and column_name = 'org_id';

  if directory_org_type is not null and directory_org_type <> 'uuid' then
    execute $sql$
      alter table public.insurance_directory
      alter column org_id type uuid
      using (
        case
          when org_id is null then public.insurance_org_uuid(insurance_id)
          when btrim(org_id::text) = '' then public.insurance_org_uuid(insurance_id)
          when org_id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
            then org_id::text::uuid
          else coalesce(
            public.insurance_org_uuid(org_id::text),
            public.insurance_org_uuid(insurance_id)
          )
        end
      )
    $sql$;
  end if;
end $$;

update public.insurance_directory
set updated_at = timezone('utc', now())
where updated_at is null;

create table if not exists public.insurance_directory_aliases (
  insurance_id text not null references public.insurance_directory(insurance_id) on delete cascade,
  alias text not null,
  normalized_alias text generated always as (public.normalize_insurance_key(alias)) stored,
  is_primary boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (insurance_id, normalized_alias),
  check (btrim(alias) <> ''),
  check (btrim(normalized_alias) <> '')
);

create unique index if not exists insurance_directory_aliases_normalized_uidx
  on public.insurance_directory_aliases (normalized_alias);

create index if not exists insurance_directory_active_idx
  on public.insurance_directory (active, insurance_id);

-- ---------------------------------------------------------------------------
-- 3) Seed the Swiss insurer directory
-- ---------------------------------------------------------------------------
insert into public.insurance_directory (
  insurance_id,
  org_id,
  display_name,
  company_name,
  active
)
values
  ('visana', '11111111-1111-4111-8111-111111111111'::uuid, 'Visana', 'Visana', true),
  ('axa', '22222222-2222-4222-8222-222222222222'::uuid, 'AXA', 'AXA', true),
  ('zurich', '33333333-3333-4333-8333-333333333333'::uuid, 'Zurich', 'Zurich', true),
  ('allianz', '44444444-4444-4444-8444-444444444444'::uuid, 'Allianz', 'Allianz', true),
  ('generali', '55555555-5555-4555-8555-555555555555'::uuid, 'Generali', 'Generali', true),
  ('helvetia', '66666666-6666-4666-8666-666666666666'::uuid, 'Helvetia', 'Helvetia', true),
  ('mobiliar', '77777777-7777-4777-8777-777777777777'::uuid, 'Die Mobiliar', 'Die Mobiliar', true),
  ('baloise', '88888888-8888-4888-8888-888888888888'::uuid, 'Baloise', 'Baloise', true),
  ('css', '99999999-9999-4999-8999-999999999999'::uuid, 'CSS', 'CSS', true),
  ('vaudoise', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid, 'Vaudoise', 'Vaudoise', true),
  ('groupe_mutuel', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid, 'Groupe Mutuel', 'Groupe Mutuel', true),
  ('helsana', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'::uuid, 'Helsana', 'Helsana', true),
  ('swica', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid, 'SWICA', 'SWICA', true),
  ('sanitas', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid, 'Sanitas', 'Sanitas', true),
  ('concordia', 'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid, 'CONCORDIA', 'CONCORDIA', true),
  ('oekk', '12121212-1212-4212-8212-121212121212'::uuid, 'ÖKK', 'ÖKK', true),
  ('sympany', '13131313-1313-4313-8313-131313131313'::uuid, 'Sympany', 'Sympany', true),
  ('assura', '14141414-1414-4414-8414-141414141414'::uuid, 'Assura', 'Assura', true),
  ('atupri', '15151515-1515-4515-8515-151515151515'::uuid, 'Atupri', 'Atupri', true),
  ('tcs', '16161616-1616-4616-8616-161616161616'::uuid, 'TCS', 'TCS', true),
  ('smile', '17171717-1717-4717-8717-171717171717'::uuid, 'Smile', 'Smile', true),
  ('dextra', '18181818-1818-4818-8818-181818181818'::uuid, 'Dextra', 'Dextra', true),
  ('coop_rechtsschutz', '19191919-1919-4919-8919-191919191919'::uuid, 'Coop Rechtsschutz', 'Coop Rechtsschutz', true),
  ('protekta', '20202020-2020-4020-8020-202020202020'::uuid, 'Protekta', 'Protekta', true),
  ('elvia', '21212121-2121-4121-8121-212121212121'::uuid, 'Elvia', 'Elvia', true),
  ('simpego', '23232323-2323-4232-8232-232323232323'::uuid, 'Simpego', 'Simpego', true),
  ('postfinance_versicherung', '24242424-2424-4242-8242-242424242424'::uuid, 'PostFinance Versicherung', 'PostFinance Versicherung', true),
  ('migros_versicherung', '25252525-2525-4252-8252-252525252525'::uuid, 'Migros Versicherung', 'Migros Versicherung', true),
  ('hdi', '26262626-2626-4262-8262-262626262626'::uuid, 'HDI', 'HDI', true),
  ('chubb', '27272727-2727-4272-8272-272727272727'::uuid, 'Chubb', 'Chubb', true),
  ('liberty', '28282828-2828-4282-8282-282828282828'::uuid, 'Liberty', 'Liberty', true),
  ('aig', '29292929-2929-4292-8292-292929292929'::uuid, 'AIG', 'AIG', true)
on conflict (insurance_id) do update
set
  org_id = excluded.org_id,
  display_name = excluded.display_name,
  company_name = excluded.company_name,
  active = excluded.active,
  updated_at = timezone('utc', now());

insert into public.insurance_directory_aliases (insurance_id, alias, is_primary)
select insurance_id, insurance_id, true
from public.insurance_directory
on conflict do nothing;

insert into public.insurance_directory_aliases (insurance_id, alias, is_primary)
select insurance_id, display_name, true
from public.insurance_directory
on conflict do nothing;

insert into public.insurance_directory_aliases (insurance_id, alias, is_primary)
select insurance_id, company_name, false
from public.insurance_directory
on conflict do nothing;

insert into public.insurance_directory_aliases (insurance_id, alias, is_primary)
values
  ('visana', 'Visana Versicherung', false),
  ('visana', 'Visana Assicurazione', false),

  ('axa', 'Axa', false),
  ('axa', 'AXA Winterthur', false),
  ('axa', 'Axa Winterthur', false),

  ('zurich', 'Zurich Versicherung', false),
  ('zurich', 'Zurich Insurance', false),
  ('zurich', 'Zurich Suisse', false),
  ('zurich', 'Zurich Schweiz', false),
  ('zurich', 'Zurich Assicurazione', false),
  ('zurich', 'Zurich Assurance', false),
  ('zurich', 'Zürich', false),

  ('allianz', 'Allianz Suisse', false),
  ('allianz', 'Allianz Versicherung', false),

  ('generali', 'Generali Suisse', false),
  ('generali', 'Generali Versicherung', false),

  ('helvetia', 'Helvetia Versicherung', false),
  ('helvetia', 'Helvetia Versicherungen', false),

  ('mobiliar', 'Mobiliar', true),
  ('mobiliar', 'La Mobiliere', false),
  ('mobiliar', 'La Mobilière', false),
  ('mobiliar', 'Mobiliar Versicherung', false),

  ('baloise', 'Basler', false),
  ('baloise', 'Basler Versicherung', false),
  ('baloise', 'Baloise Versicherung', false),
  ('baloise', 'Bâloise', false),

  ('css', 'CSS Versicherung', false),
  ('css', 'CSS Krankenversicherung', false),

  ('vaudoise', 'Vaudoise Assurances', false),
  ('vaudoise', 'Vaudoise Versicherung', false),

  ('groupe_mutuel', 'GroupeMutuel', false),
  ('groupe_mutuel', 'Groupe Mutuel Versicherung', false),

  ('helsana', 'Helsana Versicherung', false),
  ('helsana', 'Helsana Assicurazione', false),

  ('swica', 'Swica', false),
  ('swica', 'SWICA Versicherung', false),

  ('sanitas', 'Sanitas Versicherung', false),

  ('concordia', 'Concordia', false),
  ('concordia', 'Concordia Versicherung', false),

  ('oekk', 'OKK', true),
  ('oekk', 'ÖKK', false),
  ('oekk', 'OeKK', false),
  ('oekk', 'OeKK Versicherung', false),

  ('sympany', 'Sympany Versicherung', false),

  ('assura', 'Assura Versicherung', false),

  ('atupri', 'Atupri Versicherung', false),

  ('tcs', 'TCS Versicherung', false),
  ('tcs', 'TCS Assicurazione', false),

  ('smile', 'Smile Versicherung', false),
  ('smile', 'Smile Direct', false),

  ('dextra', 'Dextra Rechtsschutz', false),

  ('coop_rechtsschutz', 'Coop Legal Protection', false),

  ('protekta', 'Protekta Rechtsschutz', false),

  ('elvia', 'Elvia Versicherung', false),
  ('elvia', 'Elvia Travel', false),

  ('simpego', 'Simpego Versicherung', false),

  ('postfinance_versicherung', 'PostFinance', false),
  ('postfinance_versicherung', 'Postfinance Insurance', false),

  ('migros_versicherung', 'Migros', false),
  ('migros_versicherung', 'Migros Insurance', false),

  ('hdi', 'HDI Versicherung', false),

  ('chubb', 'Chubb Versicherung', false),

  ('liberty', 'Liberty Versicherung', false),
  ('liberty', 'Liberty Mutual', false),

  ('aig', 'AIG Versicherung', false),
  ('aig', 'American International Group', false)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 4) RLS for the directory tables
-- ---------------------------------------------------------------------------
alter table public.insurance_directory enable row level security;
alter table public.insurance_directory_aliases enable row level security;

grant select on public.insurance_directory to authenticated;
grant select on public.insurance_directory_aliases to authenticated;

drop policy if exists "insurance_directory_select_active_auth" on public.insurance_directory;
create policy "insurance_directory_select_active_auth"
on public.insurance_directory
for select
to authenticated
using (active = true);

drop policy if exists "insurance_directory_aliases_select_active_auth" on public.insurance_directory_aliases;
create policy "insurance_directory_aliases_select_active_auth"
on public.insurance_directory_aliases
for select
to authenticated
using (
  exists (
    select 1
    from public.insurance_directory d
    where d.insurance_id = insurance_directory_aliases.insurance_id
      and d.active = true
  )
);

-- ---------------------------------------------------------------------------
-- 5) Resolver functions
-- ---------------------------------------------------------------------------
drop function if exists public.resolve_insurance_profile_users(text);
drop function if exists public.resolve_insurance_directory(text);

create function public.resolve_insurance_directory(
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
  select
    d.insurance_id,
    d.org_id,
    d.display_name,
    d.company_name,
    d.active
  from public.insurance_directory_aliases a
  join public.insurance_directory d
    on d.insurance_id = a.insurance_id
  where a.normalized_alias = public.normalize_insurance_key(p_raw_name)
    and d.active = true
  order by a.is_primary desc, d.insurance_id
  limit 1;
$$;

grant execute on function public.resolve_insurance_directory(text) to authenticated;

comment on function public.resolve_insurance_directory(text)
is 'Resolves a raw Swiss insurer name to one canonical insurance_id/org_id.';

create function public.resolve_insurance_profile_users(
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
  select
    p.id::uuid,
    resolved.insurance_id,
    resolved.org_id,
    coalesce(nullif(p.display_name, ''), resolved.display_name),
    coalesce(nullif(p.company_name, ''), resolved.company_name),
    p.email
  from public.profiles p
  where p.role in ('insurance', 'assicurazione')
    and (
      p.org_id = resolved.org_id
      or p.insurance_id = resolved.org_id
    )
  order by p.updated_at desc nulls last, p.id;

  if not found then
    raise exception
      'Profilo assicurazione non collegato. Creare o collegare prima l''utente Auth.';
  end if;
end;
$$;

grant execute on function public.resolve_insurance_profile_users(text) to authenticated;

comment on function public.resolve_insurance_profile_users(text)
is 'Returns only the Auth-linked profiles of the resolved insurer.';

drop function if exists public.link_insurance_profile(uuid, text);

create function public.link_insurance_profile(
  p_auth_user_id uuid,
  p_insurance_lookup text
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  resolved record;
  auth_email text;
begin
  if p_auth_user_id is null then
    raise exception 'Auth user id mancante.';
  end if;

  select u.email
    into auth_email
  from auth.users u
  where u.id = p_auth_user_id;

  if auth_email is null then
    raise exception 'Utente Auth non trovato: %', p_auth_user_id;
  end if;

  select *
    into resolved
  from public.resolve_insurance_directory(p_insurance_lookup);

  if not found then
    raise exception
      'Assicurazione non registrata nel sistema. Aggiungerla alla directory assicurazioni.';
  end if;

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
  values (
    p_auth_user_id,
    'insurance',
    resolved.org_id,
    resolved.org_id,
    resolved.company_name,
    resolved.display_name,
    auth_email,
    timezone('utc', now())
  )
  on conflict (id) do update
  set
    role = 'insurance',
    insurance_id = excluded.insurance_id,
    org_id = excluded.org_id,
    company_name = excluded.company_name,
    display_name = excluded.display_name,
    email = coalesce(excluded.email, public.profiles.email),
    updated_at = timezone('utc', now());

  return p_auth_user_id;
end;
$$;

grant execute on function public.link_insurance_profile(uuid, text) to authenticated;

comment on function public.link_insurance_profile(uuid, text)
is 'Links one Auth user to one insurer directory entry and upserts the public.profiles row.';

-- ---------------------------------------------------------------------------
-- 6) Backfill existing insurance profiles
-- ---------------------------------------------------------------------------
update public.profiles p
set
  insurance_id = d.org_id,
  org_id = d.org_id,
  company_name = coalesce(nullif(p.company_name, ''), d.company_name),
  display_name = coalesce(nullif(p.display_name, ''), d.display_name),
  updated_at = timezone('utc', now())
from public.insurance_directory d
where p.role in ('insurance', 'assicurazione')
  and (
    p.org_id = d.org_id
    or p.insurance_id = d.org_id
  );

with text_matches as (
  select distinct on (p.id)
    p.id,
    d.org_id,
    d.company_name,
    d.display_name
  from public.profiles p
  join public.insurance_directory_aliases a
    on a.normalized_alias in (
      public.normalize_insurance_key(p.company_name),
      public.normalize_insurance_key(p.display_name),
      public.normalize_insurance_key(split_part(lower(coalesce(p.email, '')), '@', 1)),
      public.normalize_insurance_key(split_part(split_part(lower(coalesce(p.email, '')), '@', 2), '.', 1))
    )
  join public.insurance_directory d
    on d.insurance_id = a.insurance_id
  where p.role in ('insurance', 'assicurazione')
  order by p.id, a.is_primary desc, d.insurance_id
)
update public.profiles p
set
  insurance_id = m.org_id,
  org_id = m.org_id,
  company_name = coalesce(nullif(p.company_name, ''), m.company_name),
  display_name = coalesce(nullif(p.display_name, ''), m.display_name),
  updated_at = timezone('utc', now())
from text_matches m
where p.id = m.id;

commit;

-- ---------------------------------------------------------------------------
-- HOW TO LINK THE REAL AUTH USERS
-- ---------------------------------------------------------------------------
-- 1) Create the Auth user in Supabase Authentication first.
-- 2) Find the UUID:
--    select id, email
--    from auth.users
--    where lower(email) in (
--      'claims@visana.ch',
--      'claims@axa.ch',
--      'claims@zurich.ch',
--      'claims@allianz.ch'
--    );
--
-- 3) Link one Auth user to one insurer:
--    select public.link_insurance_profile(
--      'PUT-AUTH-USER-UUID-HERE'::uuid,
--      'Visana'
--    );
--
-- 4) Verify the linked profile:
--    select id, role, insurance_id, org_id, company_name, display_name, email
--    from public.profiles
--    where id = 'PUT-AUTH-USER-UUID-HERE'::uuid;
--
-- 5) Verify resolution:
--    select *
--    from public.resolve_insurance_directory('AXA Winterthur');
--
--    select *
--    from public.resolve_insurance_profile_users('Visana');
