-- Associate newly submitted customer orders with the signed-in Supabase user.
-- Existing orders are intentionally left unchanged because their owners cannot
-- be inferred safely from the current order records.
create or replace function public.attach_authenticated_customer_to_orders()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and new.customer_user_id is null then
    new.customer_user_id := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_attach_authenticated_customer_to_orders on public.orders;
create trigger trg_attach_authenticated_customer_to_orders
before insert on public.orders
for each row execute function public.attach_authenticated_customer_to_orders();
