create table if not exists public.customer_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  title text,
  first_name text not null,
  last_name text not null,
  street text,
  postal_code text,
  city text,
  country text,
  phone text,
  email text,
  profile_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.customer_profiles is
  'Private customer account profiles. Kept separate from workshop and insurance profiles.';

create or replace function public.set_customer_profiles_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists customer_profiles_set_updated_at
on public.customer_profiles;

create trigger customer_profiles_set_updated_at
before update on public.customer_profiles
for each row
execute function public.set_customer_profiles_updated_at();

alter table public.customer_profiles enable row level security;

revoke all on table public.customer_profiles from public;
revoke all on table public.customer_profiles from anon;
grant select, insert, update, delete
on table public.customer_profiles
to authenticated;

drop policy if exists customer_profiles_select_own
on public.customer_profiles;
create policy customer_profiles_select_own
on public.customer_profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists customer_profiles_insert_own
on public.customer_profiles;
create policy customer_profiles_insert_own
on public.customer_profiles
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists customer_profiles_update_own
on public.customer_profiles;
create policy customer_profiles_update_own
on public.customer_profiles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists customer_profiles_delete_own
on public.customer_profiles;
create policy customer_profiles_delete_own
on public.customer_profiles
for delete
to authenticated
using ((select auth.uid()) = user_id);
