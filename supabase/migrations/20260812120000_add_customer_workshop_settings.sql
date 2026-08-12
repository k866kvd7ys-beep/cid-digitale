alter table public.customer_profiles
add column if not exists workshop_settings jsonb;

comment on column public.customer_profiles.workshop_settings is
  'Customer-owned towing and bodyshop contact settings.';
