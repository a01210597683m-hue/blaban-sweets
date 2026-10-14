-- BLABAN-SWEETS: one-run RLS hardening + read-only security checks
-- Run once in the Supabase SQL Editor for the LIVE project.
-- This changes policies/privileges only on the five tables used by the storefront.
-- It does not delete or update any product, order, customer, or settings row.
-- Admin authorization is restricted to blabansweets339@gmail.com.

begin;

do $$
declare
  t text;
  p record;
begin
  foreach t in array array['products','orders','store_settings','store_branches','delivery_zones'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I enable row level security', t);
      -- Remove any older permissive policies on these app tables so they cannot
      -- accidentally combine with the policies below and grant extra access.
      for p in
        select policyname from pg_policies
        where schemaname = 'public' and tablename = t
      loop
        execute format('drop policy if exists %I on public.%I', p.policyname, t);
      end loop;
      execute format('revoke all on table public.%I from anon, authenticated', t);
    end if;
  end loop;
end $$;

-- Public catalog: only available products are visible. Only the store admin can write.
do $$ begin
  if to_regclass('public.products') is not null then
    grant select on public.products to anon;
    grant select, insert, update, delete on public.products to authenticated;
    create policy "Public read available products" on public.products
      for select to anon using (is_available = true);
    create policy "Admin read products" on public.products
      for select to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin insert products" on public.products
      for insert to authenticated
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin update products" on public.products
      for update to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com')
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin delete products" on public.products
      for delete to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
  end if;
end $$;

-- Customer orders: no direct anonymous access or direct customer writes.
-- Checkout must use the server-side create_store_order RPC.
do $$ begin
  if to_regclass('public.orders') is not null then
    grant select, update on public.orders to authenticated;
    create policy "Admin read orders" on public.orders
      for select to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin update orders" on public.orders
      for update to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com')
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
  end if;
end $$;

-- Store settings: readable by the storefront, writable only by the admin.
do $$ begin
  if to_regclass('public.store_settings') is not null then
    grant select on public.store_settings to anon;
    grant select, insert, update on public.store_settings to authenticated;
    create policy "Public read store settings" on public.store_settings
      for select to anon using (true);
    create policy "Admin read store settings" on public.store_settings
      for select to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin insert store settings" on public.store_settings
      for insert to authenticated
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin update store settings" on public.store_settings
      for update to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com')
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
  end if;
end $$;

-- Public visitors can see active delivery zones and branches only.
-- Management operations are restricted to the store admin.
do $$ begin
  if to_regclass('public.delivery_zones') is not null then
    grant select on public.delivery_zones to anon;
    grant select, insert, update, delete on public.delivery_zones to authenticated;
    create policy "Public read active delivery zones" on public.delivery_zones
      for select to anon using (is_active = true);
    create policy "Admin read delivery zones" on public.delivery_zones
      for select to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin insert delivery zones" on public.delivery_zones
      for insert to authenticated
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin update delivery zones" on public.delivery_zones
      for update to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com')
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin delete delivery zones" on public.delivery_zones
      for delete to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
  end if;

  if to_regclass('public.store_branches') is not null then
    grant select on public.store_branches to anon;
    grant select, insert, update, delete on public.store_branches to authenticated;
    create policy "Public read active branches" on public.store_branches
      for select to anon using (is_active = true);
    create policy "Admin read branches" on public.store_branches
      for select to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin insert branches" on public.store_branches
      for insert to authenticated
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin update branches" on public.store_branches
      for update to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com')
      with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
    create policy "Admin delete branches" on public.store_branches
      for delete to authenticated
      using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
  end if;
end $$;

commit;

-- CHECK 1: RLS must be enabled on all live storefront tables.
select c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as force_rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = any(array['products','orders','store_settings','store_branches','delivery_zones'])
order by c.relname;

-- CHECK 2: inspect the checkout RPC. Review its definition to confirm that it:
-- (a) looks up prices in products rather than trusting client prices,
-- (b) validates quantity, product availability, delivery zone and branch,
-- (c) computes subtotal/delivery/total server-side,
-- (d) uses SECURITY DEFINER only with a fixed safe search_path,
-- (e) limits executable access to intended roles.
select p.proname,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,
       p.proconfig as function_settings,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_can_execute,
       pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'create_store_order';

-- CHECK 3: list policies after hardening for a quick verification.
select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename = any(array['products','orders','store_settings','store_branches','delivery_zones'])
order by tablename, policyname;
