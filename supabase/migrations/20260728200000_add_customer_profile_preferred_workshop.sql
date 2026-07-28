alter table public.customer_profiles
add column if not exists preferred_workshop jsonb;
