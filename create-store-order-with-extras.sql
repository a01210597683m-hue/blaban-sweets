-- Additive RPC for optional extras.
-- Requires public.product_extras and the existing public.create_store_order RPC.
create or replace function public.create_store_order_with_extras(
  p_customer_name text,
  p_customer_phone text,
  p_delivery_address text,
  p_notes text,
  p_items jsonb,
  p_delivery_zone_id uuid,
  p_branch_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_base jsonb;
  v_items jsonb;
  v_subtotal numeric(10,2);
  v_fee numeric(10,2);
  v_order_id uuid;
  v_line jsonb;
  v_product_id uuid;
  v_quantity integer;
  v_product record;
  v_extra jsonb;
  v_extra_id uuid;
  v_extra_row record;
  v_extra_total numeric(10,2);
  v_line_extras jsonb;
  v_new_items jsonb := '[]'::jsonb;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 30 then
    raise exception 'بيانات المنتجات غير صحيحة.';
  end if;

  select jsonb_agg(jsonb_build_object('id', x->>'id', 'quantity', x->>'quantity'))
    into v_items
  from jsonb_array_elements(p_items) x;

  v_base := public.create_store_order(
    p_customer_name, p_customer_phone, p_delivery_address, p_notes,
    v_items, p_delivery_zone_id, p_branch_id
  );

  v_order_id := (v_base->>'id')::uuid;
  v_fee := coalesce((v_base->>'delivery_fee')::numeric,0);
  v_subtotal := 0;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_line->>'id')::uuid;
    v_quantity := (v_line->>'quantity')::integer;
    select p.id, p.name, p.price, p.image_url, p.parent_product_id
      into v_product
    from public.products p
    where p.id = v_product_id and p.is_available = true;
    if not found then raise exception 'منتج واحد أو أكثر غير متاح حاليًا.'; end if;

    v_extra_total := 0;
    v_line_extras := '[]'::jsonb;
    if jsonb_typeof(v_line->'extras') = 'array' then
      for v_extra in select value from jsonb_array_elements(v_line->'extras')
      loop
        if coalesce(v_extra->>'id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
          raise exception 'بيانات الإضافات غير صحيحة.';
        end if;
        v_extra_id := (v_extra->>'id')::uuid;
        select e.id, e.name, e.price
          into v_extra_row
        from public.product_extras e
        where e.id = v_extra_id
          and e.is_available = true
          and e.product_id = coalesce(v_product.parent_product_id, v_product.id);
        if not found then raise exception 'إضافة غير متاحة لهذا المنتج.'; end if;
        v_extra_total := v_extra_total + v_extra_row.price;
        v_line_extras := v_line_extras || jsonb_build_array(jsonb_build_object('id',v_extra_row.id,'name',v_extra_row.name,'price',v_extra_row.price));
      end loop;
    end if;

    v_subtotal := v_subtotal + (v_product.price + v_extra_total) * v_quantity;
    v_new_items := v_new_items || jsonb_build_array(jsonb_build_object(
      'id',v_product.id,'name',v_product.name,'price',v_product.price,
      'quantity',v_quantity,'image_url',v_product.image_url,
      'extras',v_line_extras,'extras_subtotal',v_extra_total*v_quantity,
      'subtotal',(v_product.price+v_extra_total)*v_quantity
    ));
  end loop;

  update public.orders
    set items = v_new_items,
        subtotal_amount = v_subtotal,
        total_amount = v_subtotal + v_fee,
        updated_at = now()
    where id = v_order_id;

  return jsonb_build_object(
    'id',v_order_id,'order_number',v_base->>'order_number',
    'subtotal_amount',v_subtotal,'delivery_fee',v_fee,
    'total_amount',v_subtotal+v_fee,'items',v_new_items,
    'created_at',v_base->'created_at'
  );
end;
$function$;

revoke all on function public.create_store_order_with_extras(text,text,text,text,jsonb,uuid,uuid) from public;
grant execute on function public.create_store_order_with_extras(text,text,text,text,jsonb,uuid,uuid) to anon, authenticated;
