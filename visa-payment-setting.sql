-- Optional external payment-provider checkout link. Leave empty until you receive a real provider URL.
alter table public.store_settings add column if not exists visa_payment_url text;
