alter table if exists public.claims
drop constraint if exists claims_status_check;

alter table public.claims
add constraint claims_status_check
check (
  status is null
  or status in (
    'warten_auf_freigabe',
    'freigegeben',
    'freigabe',
    'kein_freigabe',
    'geschlossen'
  )
);
