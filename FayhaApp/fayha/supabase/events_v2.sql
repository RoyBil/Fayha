-- ============================================================
-- events_v2.sql
-- Run in Supabase SQL editor (idempotent — safe to re-run).
--
-- Adds:
--   • concerts.maps_url — optional Google Maps link for events
-- ============================================================

ALTER TABLE public.concerts
  ADD COLUMN IF NOT EXISTS maps_url text;
