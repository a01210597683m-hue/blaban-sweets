-- Blaban Sweets: initial Supabase/PostgreSQL schema
-- Apply in Supabase SQL Editor only after creating your own project.
-- No real products, prices, branches, payment credentials, or owner account are seeded.
create extension if not exists pgcrypto;

create type public.app_role as enum ('owner', 'store_admin', 'order_manager', 'content_manager');
create type public.product_status as enum ('draft', 'published', 'hidden', 'unavailable');
create type public.order_status as enum ('new', 'confirming', 'preparing', 'out_for_delivery', 'completed', 'cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role public.app_role not null default 'content_manager',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text,
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete set null,
  name_ar text not null,
  name_en text,
  description_ar text,
  description_en text,
  image_urls text[] not null default '{}',
  price_egp numeric(10,2) not null check (price_egp >= 0),
  sale_price_egp numeric(10,2) check (sale_price_egp >= 0 and sale_price_egp <= price_egp),
  options jsonb not null default '[]'::jsonb,
  add_ons jsonb not null default '[]'::jsonb,
  stock_quantity integer check (stock_quantity >= 0),
  status public.product_status not null default 'draft',
  is_featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  governorate text,
  city text,
  area text,
  address_details text,
  phone text,
  opening_hours text,
  maps_url text,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  fee_egp numeric(10,2) not null default 0 check (fee_egp >= 0),
  minimum_order_egp numeric(10,2) not null default 0 check (minimum_order_egp >= 0),
  is_active boolean not null default false
);

create table public.store_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_name text not null,
  customer_phone text not null,
  customer_email text,
  delivery_address jsonb not null,
  delivery_zone_id uuid references public.delivery_zones(id) on delete set null,
  items jsonb not null,
  subtotal_egp numeric(10,2) not null check (subtotal_egp >= 0),
  discount_egp numeric(10,2) not null default 0 check (discount_egp >= 0),
  delivery_fee_egp numeric(10,2) not null default 0 check (delivery_fee_egp >= 0),
  total_egp numeric(10,2) not null check (total_egp >= 0),
  status public.order_status not null default 'new',
  payment_method text,
  payment_status text not null default 'not_configured',
  customer_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  old_status public.order_status,
  new_status public.order_status not null,
  changed_by uuid references auth.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text,
  target_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.branches enable row level security;
alter table public.delivery_zones enable row level security;
alter table public.store_settings enable row level security;
alter table public.orders enable row level security;
alter table public.order_status_history enable row level security;
alter table public.audit_log enable row level security;

-- Public visitors can read only published products and active categories/branches.
create policy "Public read active categories" on public.categories
for select to anon, authenticated using (is_active = true);
create policy "Public read published products" on public.products
for select to anon, authenticated using (status = 'published');
create policy "Public read active branches" on public.branches
for select to anon, authenticated using (is_active = true);

-- Intentionally no client-side write policies for orders or admin tables.
-- Production order creation and admin mutations must go through trusted server
-- functions that validate prices, availability, role permissions and ownership.
-- Never expose the Supabase service-role key in browser code.
