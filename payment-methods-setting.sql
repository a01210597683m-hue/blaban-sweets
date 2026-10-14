-- Adds editable payment-method choices for the store checkout.
alter table public.store_settings
add column if not exists payment_methods text;
