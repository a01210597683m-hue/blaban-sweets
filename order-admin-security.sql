-- Secure customer orders and allow only the store admin to read/update them.
-- Run in Supabase SQL Editor. Admin login email: blabansweets339@gmail.com

alter table public.orders enable row level security;
alter table public.products enable row level security;

-- Customers submit orders only through the validated SECURITY DEFINER checkout function.
revoke all on table public.orders from anon;
grant select, update on table public.orders to authenticated;

-- Remove existing order policies, then apply one explicit admin-only policy.
do $$
declare p record;
begin
  for p in
    select policyname from pg_policies
    where schemaname='public' and tablename='orders'
  loop
    execute format('drop policy if exists %I on public.orders', p.policyname);
  end loop;
end $$;

create policy "Only store admin can view orders"
on public.orders for select to authenticated
using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');

create policy "Only store admin can update orders"
on public.orders for update to authenticated
using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com')
with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');

-- Keep public catalog access limited to available products; permit the admin to manage the catalog.
revoke all on table public.products from anon;
grant select on table public.products to anon;
grant select, insert, update, delete on table public.products to authenticated;

drop policy if exists "Public can view available products" on public.products;
create policy "Public can view available products"
on public.products for select to anon
using (is_available = true);

drop policy if exists "Authenticated can view products" on public.products;
create policy "Authenticated can view products"
on public.products for select to authenticated
using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');

drop policy if exists "Store admin can insert products" on public.products;
create policy "Store admin can insert products"
on public.products for insert to authenticated
with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');

drop policy if exists "Store admin can update products" on public.products;
create policy "Store admin can update products"
on public.products for update to authenticated
using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com')
with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');

drop policy if exists "Store admin can delete products" on public.products;
create policy "Store admin can delete products"
on public.products for delete to authenticated
using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');

-- Do not expose the orders table directly to visitors. The public checkout RPC remains the order-creation path.
