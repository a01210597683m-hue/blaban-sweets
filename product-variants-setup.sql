-- BLABAN-SWEETS: دعم أصناف متعددة داخل المنتج الواحد
-- شغّلي هذا الملف مرة واحدة في Supabase SQL Editor قبل إضافة الأصناف.
-- كل صنف هو سجل منتج تابع للمنتج الأساسي؛ لذلك يحتفظ بسعره وصورته،
-- ويظل متوافقًا مع سلة الطلبات ودالة create_store_order الحالية.

alter table public.products
  add column if not exists parent_product_id uuid null
  references public.products(id) on delete cascade;

create index if not exists products_parent_product_id_idx
  on public.products(parent_product_id);

comment on column public.products.parent_product_id is
  'المنتج الأساسي الذي ينتمي إليه الصنف؛ NULL للمنتجات الأساسية.';
