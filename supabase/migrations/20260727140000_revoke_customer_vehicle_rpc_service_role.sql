revoke execute
on function public.set_customer_primary_vehicle(text)
from service_role;

revoke execute
on function public.delete_customer_vehicle(text)
from service_role;
