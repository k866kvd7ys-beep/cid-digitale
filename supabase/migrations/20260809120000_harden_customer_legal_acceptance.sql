create or replace function public.apply_customer_legal_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  auth_metadata jsonb;
  server_accepted_at timestamptz;
begin
  -- Legal acceptance is immutable through customer_profiles. This also keeps
  -- legacy all-null profiles all-null on every subsequent profile update.
  if tg_op = 'UPDATE' then
    new.privacy_accepted_at := old.privacy_accepted_at;
    new.privacy_version := old.privacy_version;
    new.terms_accepted_at := old.terms_accepted_at;
    new.terms_version := old.terms_version;
    return new;
  end if;

  -- Values submitted directly to customer_profiles are never authoritative.
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

  -- Auth metadata is only the registration-flow signal. The database accepts
  -- the exact current document versions and never persists a client timestamp.
  if nullif(btrim(auth_metadata ->> 'privacy_version'), '')
       is distinct from '2026-08-08'
     or nullif(btrim(auth_metadata ->> 'terms_version'), '')
       is distinct from '2026-08-08'
     or nullif(btrim(auth_metadata ->> 'privacy_accepted_at'), '') is null
     or nullif(btrim(auth_metadata ->> 'terms_accepted_at'), '') is null then
    return new;
  end if;

  server_accepted_at := now();
  new.privacy_accepted_at := server_accepted_at;
  new.privacy_version := '2026-08-08';
  new.terms_accepted_at := server_accepted_at;
  new.terms_version := '2026-08-08';
  return new;
end;
$$;
