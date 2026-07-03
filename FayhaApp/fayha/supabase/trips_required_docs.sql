-- Add per-group configurable required document types.
-- Defaults to passport + profile_photo (the original hard-coded requirement).
ALTER TABLE public.trip_groups
  ADD COLUMN IF NOT EXISTS required_doc_types text[] NOT NULL DEFAULT ARRAY['passport','profile_photo'];
