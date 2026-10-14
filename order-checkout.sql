-- Blaban-sweets: safe public checkout RPC
-- Run this file in Supabase SQL Editor after reviewing it.
create or replace function public.create_store_order(
  p_customer_name text,
  p_customer_phone text,
  p_delivery_address text,
  p_notes text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_items jsonb;
  v_total numeric(10,2);
  v_order public.orders%rowtype;
begin
  if nullif(trim(p_customer_name), '') is null or char_length(trim(p_customer_name)) > 120 then
    raise exception 'اكتبي اسم صحيح (حتى 120 حرفًا).';
  end if;
  if nullif(trim(p_customer_phone), '') is null or char_length(trim(p_customer_phone)) > 30 then
    raise exception 'اكتبي رقم هاتف صحيح.';
  end if;
  if nullif(trim(p_delivery_address), '') is null or char_length(trim(p_delivery_address)) > 500 then
    raise exception 'اكتبي عنوان التوصيل أو الاستلام.';
  end if;
  if p_notes is not null and char_length(p_notes) > 1000 then
    raise exception 'الملاحظات طويلة جدًا.';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 30 then
    raise exception 'اختاري منتجًا واحدًا على الأقل (بحد أقصى 30 صنفًا).';
  end if;

  with requested as (
    select (x->>'id')::uuid as product_id,
           greatest(1, least(20, coalesce((x->>'quantity')::integer, 1))) as quantity
    from jsonb_array_elements(p_items) x
  ),
  grouped as (
    select product_id, sum(quantity)::integer as quantity
    from requested group by product_id
  ),
  valid_products as (
    select p.id, p.name, p.price, p.image_url, g.quantity
    from grouped g
    join public.products p on p.id = g.product_id
    where p.is_available = true
  )
  select jsonb_agg(jsonb_build_object(
           'id', id, 'name', name, 'price', price, 'quantity', quantity,
           'image_url', image_url, 'subtotal', price * quantity
         )),
         sum(price * quantity)
    into v_items, v_total
    from valid_products;

  if v_items is null or jsonb_array_length(v_items) = 0 then
    raise exception 'المنتجات المختارة غير متاحة الآن. حدّثي المنيو وحاولي مرة أخرى.';
  end if;

  insert into public.orders(customer_name, customer_phone, delivery_address, notes, items, total_amount)
  values(trim(p_customer_name), trim(p_customer_phone), trim(p_delivery_address),
         nullif(trim(coalesce(p_notes, '')), ''), v_items, v_total)
  returning * into v_order;

  return jsonb_build_object(
    'id', v_order.id,
    'order_number', v_order.order_number,
    'total_amount', v_order.total_amount,
    'items', v_order.items,
    'created_at', v_order.created_at
  );
end;
$$;

revoke all on function public.create_store_order(text,text,text,text,jsonb) from public;
grant execute on function public.create_store_order(text,text,text,text,jsonb) to anon, authenticated;
