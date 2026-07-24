begin;

create table if not exists public.insurance_information_response_notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  event_type text not null check (
    event_type = 'customer_information_response_submitted'
  ),
  claim_id text not null references public.claims(id) on delete cascade,
  information_request_id uuid not null
    references public.insurance_information_requests(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  claim_reference text not null,
  metadata jsonb not null default '{}'::jsonb check (
    jsonb_typeof(metadata) = 'object'
  ),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  is_read boolean generated always as (read_at is not null) stored,
  unique (information_request_id, event_type)
);

create index if not exists insurance_information_response_notifications_recipient_idx
  on public.insurance_information_response_notifications (
    recipient_user_id,
    created_at desc
  );

create index if not exists insurance_information_response_notifications_unread_idx
  on public.insurance_information_response_notifications (
    recipient_user_id,
    claim_id,
    created_at desc
  )
  where read_at is null;

alter table public.insurance_information_response_notifications
  enable row level security;
alter table public.insurance_information_response_notifications
  replica identity full;

revoke all on public.insurance_information_response_notifications
  from anon, authenticated;
grant select on public.insurance_information_response_notifications
  to authenticated;

drop policy if exists
  insurance_information_response_notifications_select_recipient
  on public.insurance_information_response_notifications;
create policy insurance_information_response_notifications_select_recipient
on public.insurance_information_response_notifications
for select
to authenticated
using (
  recipient_user_id = auth.uid()
  and public.is_claim_insurance_editor(claim_id)
);

create or replace function public.create_insurance_information_response_notification()
returns trigger
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_recipient_user_id uuid;
begin
  select coalesce(c.insurance_user_id, new.insurance_user_id)
  into v_recipient_user_id
  from public.claims c
  where c.id = new.claim_id;

  insert into public.insurance_information_response_notifications (
    event_type,
    claim_id,
    information_request_id,
    recipient_user_id,
    claim_reference,
    metadata
  ) values (
    'customer_information_response_submitted',
    new.claim_id,
    new.id,
    v_recipient_user_id,
    upper(left(new.claim_id, 8)),
    jsonb_build_object('record_type', new.record_type)
  )
  on conflict (information_request_id, event_type) do nothing;

  return new;
end;
$$;

revoke all on function
  public.create_insurance_information_response_notification()
  from public, anon, authenticated;

drop trigger if exists
  insurance_information_request_submitted_notification
  on public.insurance_information_requests;
create trigger insurance_information_request_submitted_notification
after update of status on public.insurance_information_requests
for each row
when (
  new.status = 'submitted'
  and old.status is distinct from new.status
)
execute function public.create_insurance_information_response_notification();

create or replace function
  public.mark_insurance_information_response_notifications_read(
    p_claim_id text
  )
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_updated integer;
begin
  if auth.uid() is null
      or not public.is_claim_insurance_editor(p_claim_id) then
    raise exception 'insurance_notification_not_authorized';
  end if;

  update public.insurance_information_response_notifications
  set read_at = now()
  where claim_id = p_claim_id
    and recipient_user_id = auth.uid()
    and event_type = 'customer_information_response_submitted'
    and read_at is null;

  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

revoke all on function
  public.mark_insurance_information_response_notifications_read(text)
  from public, anon, authenticated;
grant execute on function
  public.mark_insurance_information_response_notifications_read(text)
  to authenticated;

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'insurance_information_response_notifications'
  ) then
    alter publication supabase_realtime
      add table public.insurance_information_response_notifications;
  end if;
end;
$$;

commit;
