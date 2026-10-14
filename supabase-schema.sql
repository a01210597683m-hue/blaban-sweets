-- حلو بلبن: قاعدة بيانات أولية لـ Supabase
-- شغّلي هذا الملف من SQL Editor داخل مشروع Supabase بعد مراجعته.
-- لا تضعي service_role key في أي ملف من ملفات الموقع.

create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  category text,
  description text,
  price numeric(10,2) not null check (price >= 0),
  image_url text,
  parent_product_id uuid references public.products(id) on delete cascade,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null default ('BL-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
  customer_name text not null,
  customer_phone text not null,
  delivery_address text not null,
  notes text,
  items jsonb not null default '[]'::jsonb,
  total_amount numeric(10,2) not null check (total_amount >= 0),
  status text not null default 'new' check (status in ('new','confirmed','preparing','out_for_delivery','delivered','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products enable row level security;
alter table public.orders enable row level security;

-- الزوار يمكنهم رؤية المنتجات المتاحة فقط.
drop policy if exists "Public can view available products" on public.products;
create policy "Public can view available products"
on public.products for select
to anon, authenticated
using (is_available = true);

-- الإدارة: حسابات مسجلة فقط. يفضّل تقييد الإدارة بقائمة المستخدمين/دور admin
-- قبل نشر لوحة الإدارة للإنتاج. هذه السياسة تحتاج جدول صلاحيات موثوقًا قبل الإطلاق.
-- لذلك لا نمنح أي كتابة للمستخدمين المسجلين افتراضيًا في هذا الملف.

-- لا توجد سياسات عامة لقراءة الطلبات أو تعديلها، لحماية بيانات العملاء.
-- لا تضيفي سياسات orders العامة. إعداد إرسال الطلبات يحتاج دالة خادمية
-- تتحقق من الأسعار من قاعدة البيانات وتحد من إساءة الاستخدام.

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists products_touch_updated_at on public.products;
create trigger products_touch_updated_at before update on public.products
for each row execute function public.touch_updated_at();

drop trigger if exists orders_touch_updated_at on public.orders;
create trigger orders_touch_updated_at before update on public.orders
for each row execute function public.touch_updated_at();

-- مهم: هذا مخطط بداية آمن نسبيًا، وليس إعدادًا مكتملًا للإنتاج.
-- قبل تفعيل لوحة الإدارة نضيف جدول admin_users وسياسات RLS مرتبطة به،
-- ثم ننشئ حساب الإدارة ونتأكد أن العميل لا يستطيع تعديل الأسعار أو قراءة بيانات الآخرين.

-- إعدادات قابلة للتحرير من لوحة الإدارة وتُعرض في واجهة المتجر.
create table if not exists public.store_settings (
  id integer primary key check (id = 1),
  store_name_ar text not null default 'حلو ب-لبن',
  store_name_en text not null default 'Blaban-sweets',
  tagline text not null default 'مع حلو ب-لبن حلى أيامك',
  logo_url text,
  primary_color text not null default '#153b74' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  accent_color text not null default '#ffdfeb' check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  hero_image_url text,
  hero_title text not null default 'كل يوم محتاج حاجة حلوة',
  hero_description text not null default 'من أول معلقة لآخر لقمة… خلي للحلاوة مكان في يومك.',
  story_title text not null default 'حلى أيامك، على طريقتك',
  story_description text not null default 'اكتشف عالم حلو ب-لبن.',
  cta_title text not null default 'جاهزين نخلي التجربة أحلى؟',
  cta_description text not null default 'خلي للحلاوة مكان في يومك.',
  updated_at timestamptz not null default now()
);
alter table public.store_settings enable row level security;
drop policy if exists "Public can read store settings" on public.store_settings;
create policy "Public can read store settings" on public.store_settings
for select to anon, authenticated using (true);
drop policy if exists "Store admin can insert settings" on public.store_settings;
create policy "Store admin can insert settings" on public.store_settings
for insert to authenticated
with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
drop policy if exists "Store admin can update settings" on public.store_settings;
create policy "Store admin can update settings" on public.store_settings
for update to authenticated
using ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com')
with check ((auth.jwt() ->> 'email') = 'blabansweets339@gmail.com');
insert into public.store_settings (id) values (1) on conflict (id) do nothing;
