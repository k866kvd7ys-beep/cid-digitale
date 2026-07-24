with target_users as (
  select
    c.id as claim_id,
    c.insurance_user_id as user_id
  from public.claims c
  where c.id = '03101a48-c079-411f-a5d9-3c5a988eec27'
    and c.insurance_user_id is not null

  union

  select
    c.id as claim_id,
    p.id as user_id
  from public.claims c
  join public.profiles p
    on p.insurance_id = coalesce(c.insurer_org_id, c.suggested_insurer_org_id)
   and p.role in ('insurance', 'assicurazione')
  where c.id = '03101a48-c079-411f-a5d9-3c5a988eec27'
    and c.insurance_user_id is null
)
insert into public.claim_participants (claim_id, user_id, role)
select t.claim_id, t.user_id, 'insurance'
from target_users t
where t.user_id is not null
  and not exists (
    select 1
    from public.claim_participants cp
    where cp.claim_id = t.claim_id
      and cp.user_id = t.user_id
      and cp.role = 'insurance'
  );
