begin;
alter table public.profiles
  add column if not exists address text;
alter table public.profiles
  add column if not exists phone text;
comment on column public.profiles.address is
  'Public contact address managed by the authenticated workshop profile.';
comment on column public.profiles.phone is
  'Public contact phone managed by the authenticated workshop profile.';
commit;
