begin;

create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  user_email text not null,
  request_type text not null,
  subject text not null,
  message text not null,
  attachment_urls jsonb not null default '[]'::jsonb,
  status text not null default 'open',
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_requests_request_type_check
    check (request_type in ('problem', 'question', 'suggestion')),
  constraint support_requests_status_check
    check (status in ('open', 'in_progress', 'resolved')),
  constraint support_requests_email_check
    check (length(btrim(user_email)) between 3 and 320),
  constraint support_requests_subject_check
    check (length(btrim(subject)) between 3 and 120),
  constraint support_requests_message_check
    check (length(btrim(message)) between 10 and 2000),
  constraint support_requests_attachments_array_check
    check (
      jsonb_typeof(attachment_urls) = 'array'
      and jsonb_array_length(attachment_urls) <= 3
    )
);

create index support_requests_created_by_created_at_idx
  on public.support_requests (created_by, created_at desc);

create index support_requests_status_created_at_idx
  on public.support_requests (status, created_at desc);

create function public.set_support_request_updated_at()
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

create trigger support_requests_set_updated_at
before update on public.support_requests
for each row execute function public.set_support_request_updated_at();

alter table public.support_requests enable row level security;

revoke all on table public.support_requests from anon;
revoke all on table public.support_requests from authenticated;
grant select, insert on table public.support_requests to authenticated;
grant all on table public.support_requests to service_role;

create policy support_requests_select_own
on public.support_requests
for select
to authenticated
using (auth.uid() = created_by);

create policy support_requests_insert_own
on public.support_requests
for insert
to authenticated
with check (
  auth.uid() = created_by
  and status = 'open'
  and notified_at is null
);

revoke all on function public.set_support_request_updated_at() from public;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'support-attachments',
  'support-attachments',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy support_attachments_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'support-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy support_attachments_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'support-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy support_attachments_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'support-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

comment on table public.support_requests is
  'Private CID Cliente support requests and secure attachment metadata.';

commit;
