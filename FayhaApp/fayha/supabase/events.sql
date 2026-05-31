-- ============================================================
-- Fayha — Admins can add events (concerts / big rehearsals)
-- Run once in the Supabase SQL Editor.
-- ============================================================

alter table public.concerts
  add column if not exists kind text default 'concert';  -- concert | rehearsal

drop policy if exists "admins manage concerts" on public.concerts;
create policy "admins manage concerts" on public.concerts
  for all
  using (public.my_role() in ('admin', 'superAdmin'))
  with check (public.my_role() in ('admin', 'superAdmin'));
