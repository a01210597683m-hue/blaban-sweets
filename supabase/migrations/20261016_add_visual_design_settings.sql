-- Additive setting used by the admin appearance controls.
-- Safe to re-run; existing store settings and commerce data are preserved.
ALTER TABLE public.store_settings
  ADD COLUMN IF NOT EXISTS design_settings jsonb NOT NULL
  DEFAULT '{"storeLayout":"classic","adminTheme":"navy","cardRadius":20,"buttonStyle":"rounded"}'::jsonb;
