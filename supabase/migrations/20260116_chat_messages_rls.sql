-- Enable RLS and allow authenticated users to read/insert chat messages
alter table if exists public.chat_messages enable row level security;

drop policy if exists "chat_messages_select_auth" on public.chat_messages;
create policy "chat_messages_select_auth"
on public.chat_messages
for select
to authenticated
using (true);

drop policy if exists "chat_messages_insert_auth" on public.chat_messages;
create policy "chat_messages_insert_auth"
on public.chat_messages
for insert
to authenticated
with check (true);
