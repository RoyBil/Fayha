-- ============================================================
-- Fayha — Store the sender's name on each direct message.
-- Run once in the Supabase SQL Editor.
-- ============================================================

alter table public.direct_messages
  add column if not exists sender_name text;
