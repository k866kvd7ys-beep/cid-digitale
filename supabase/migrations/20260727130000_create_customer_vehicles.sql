create table public.customer_vehicles (
  user_id uuid not null
    references public.customer_profiles (user_id)
    on delete cascade,
  vehicle_id text not null,
  plate text not null default '',
  brand text not null default '',
  model text not null default '',
  vin text not null default '',
  mileage text not null default '',
  first_registration text not null default '',
  insurance_company text not null default '',
  policy_number text not null default '',
  claim_number text not null default '',
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (user_id, vehicle_id),
  constraint customer_vehicles_vehicle_id_not_empty
    check (btrim(vehicle_id) <> '')
);

comment on table public.customer_vehicles is
  'Vehicles belonging to authenticated customer profiles.';

create unique index customer_vehicles_one_primary_per_user
on public.customer_vehicles (user_id)
where is_primary;

create or replace function public.set_customer_vehicles_updated_at()
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

revoke all
on function public.set_customer_vehicles_updated_at()
from public, anon;

create trigger customer_vehicles_set_updated_at
before update on public.customer_vehicles
for each row
execute function public.set_customer_vehicles_updated_at();

create or replace function public.set_first_customer_vehicle_primary()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.customer_vehicles
    where user_id = new.user_id
  ) then
    new.is_primary = true;
  end if;
  return new;
end;
$$;

revoke all
on function public.set_first_customer_vehicle_primary()
from public, anon;

create trigger customer_vehicles_set_first_primary
before insert on public.customer_vehicles
for each row
execute function public.set_first_customer_vehicle_primary();

alter table public.customer_vehicles enable row level security;

revoke all on table public.customer_vehicles from public;
revoke all on table public.customer_vehicles from anon;

grant select, insert, update, delete
on table public.customer_vehicles
to authenticated;

create policy customer_vehicles_select_own
on public.customer_vehicles
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy customer_vehicles_insert_own
on public.customer_vehicles
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy customer_vehicles_update_own
on public.customer_vehicles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy customer_vehicles_delete_own
on public.customer_vehicles
for delete
to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.set_customer_primary_vehicle(
  p_vehicle_id text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.customer_vehicles
    where user_id = (select auth.uid())
      and vehicle_id = p_vehicle_id
  ) then
    raise exception 'customer_vehicle_not_found'
      using errcode = 'P0002';
  end if;

  update public.customer_vehicles
  set is_primary = false
  where user_id = (select auth.uid())
    and is_primary
    and vehicle_id <> p_vehicle_id;

  update public.customer_vehicles
  set is_primary = true
  where user_id = (select auth.uid())
    and vehicle_id = p_vehicle_id;
end;
$$;

revoke all
on function public.set_customer_primary_vehicle(text)
from public, anon;

grant execute
on function public.set_customer_primary_vehicle(text)
to authenticated;

create or replace function public.delete_customer_vehicle(
  p_vehicle_id text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  deleted_was_primary boolean;
  next_primary_id text;
begin
  delete from public.customer_vehicles
  where user_id = (select auth.uid())
    and vehicle_id = p_vehicle_id
  returning is_primary into deleted_was_primary;

  if not found then
    raise exception 'customer_vehicle_not_found'
      using errcode = 'P0002';
  end if;

  if deleted_was_primary then
    select vehicle_id
    into next_primary_id
    from public.customer_vehicles
    where user_id = (select auth.uid())
    order by created_at, vehicle_id
    limit 1;

    if next_primary_id is not null then
      update public.customer_vehicles
      set is_primary = true
      where user_id = (select auth.uid())
        and vehicle_id = next_primary_id;
    end if;
  end if;
end;
$$;

revoke all
on function public.delete_customer_vehicle(text)
from public, anon;

grant execute
on function public.delete_customer_vehicle(text)
to authenticated;
