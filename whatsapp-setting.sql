-- Add an optional WhatsApp number that can be managed from the store admin panel.
alter table public.store_settings
add column if not exists whatsapp_number text;
