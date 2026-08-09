alter table public.customer_profiles
  add column if not exists privacy_accepted_at timestamptz,
  add column if not exists privacy_version text,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists terms_version text;

comment on column public.customer_profiles.privacy_accepted_at is
  'UTC instant at which the customer accepted the recorded Privacy Policy version.';
comment on column public.customer_profiles.privacy_version is
  'Privacy Policy version explicitly accepted by the customer.';
comment on column public.customer_profiles.terms_accepted_at is
  'UTC instant at which the customer accepted the recorded Terms of Use version.';
comment on column public.customer_profiles.terms_version is
  'Terms of Use version explicitly accepted by the customer.';

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'customer_profiles_legal_acceptance_all_or_none'
      and conrelid = 'public.customer_profiles'::regclass
  ) then
    alter table public.customer_profiles
      add constraint customer_profiles_legal_acceptance_all_or_none
      check (
        (
          privacy_accepted_at is null
          and privacy_version is null
          and terms_accepted_at is null
          and terms_version is null
        )
        or
        (
          privacy_accepted_at is not null
          and nullif(btrim(privacy_version), '') is not null
          and terms_accepted_at is not null
          and nullif(btrim(terms_version), '') is not null
        )
      );
  end if;
end;
$$;

create or replace function public.apply_customer_legal_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  auth_metadata jsonb;
  metadata_privacy_accepted_at timestamptz;
  metadata_privacy_version text;
  metadata_terms_accepted_at timestamptz;
  metadata_terms_version text;
begin
  -- Once a complete acceptance has been recorded, profile updates and retries
  -- must preserve it exactly, including when consent columns are omitted.
  if tg_op = 'UPDATE'
     and old.privacy_accepted_at is not null
     and nullif(btrim(old.privacy_version), '') is not null
     and old.terms_accepted_at is not null
     and nullif(btrim(old.terms_version), '') is not null then
    new.privacy_accepted_at := old.privacy_accepted_at;
    new.privacy_version := old.privacy_version;
    new.terms_accepted_at := old.terms_accepted_at;
    new.terms_version := old.terms_version;
    return new;
  end if;

  -- Consent values supplied through the public profile API are ignored. The
  -- only accepted source is the metadata captured by Auth during sign-up.
  new.privacy_accepted_at := null;
  new.privacy_version := null;
  new.terms_accepted_at := null;
  new.terms_version := null;

  select coalesce(users.raw_user_meta_data, '{}'::jsonb)
  into auth_metadata
  from auth.users
  where users.id = new.user_id;

  if auth_metadata is null or jsonb_typeof(auth_metadata) <> 'object' then
    return new;
  end if;

  metadata_privacy_version :=
    nullif(btrim(auth_metadata ->> 'privacy_version'), '');
  metadata_terms_version :=
    nullif(btrim(auth_metadata ->> 'terms_version'), '');

  if metadata_privacy_version is null or metadata_terms_version is null then
    return new;
  end if;

  begin
    metadata_privacy_accepted_at :=
      (auth_metadata ->> 'privacy_accepted_at')::timestamptz;
    metadata_terms_accepted_at :=
      (auth_metadata ->> 'terms_accepted_at')::timestamptz;
  exception
    when others then
      return new;
  end;

  if metadata_privacy_accepted_at is null
     or metadata_terms_accepted_at is null then
    return new;
  end if;

  new.privacy_accepted_at := metadata_privacy_accepted_at;
  new.privacy_version := metadata_privacy_version;
  new.terms_accepted_at := metadata_terms_accepted_at;
  new.terms_version := metadata_terms_version;
  return new;
end;
$$;

drop trigger if exists customer_profiles_apply_legal_acceptance
on public.customer_profiles;

create trigger customer_profiles_apply_legal_acceptance
before insert or update on public.customer_profiles
for each row
execute function public.apply_customer_legal_acceptance();
