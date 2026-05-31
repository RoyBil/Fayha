-- ============================================================
-- Fayha — Updated branch rehearsal schedules
-- Run once in the Supabase SQL Editor.
-- ============================================================

update public.branches set rehearsal_schedule = 'Thu · Fri · Sat — 6:00–9:00 PM'
  where id = 'tripoli';
update public.branches set rehearsal_schedule = 'Mon · Tue · Wed — 6:00–9:00 PM'
  where id = 'beirut';
update public.branches set rehearsal_schedule = 'Wed · Thu · Fri — 6:00–9:00 PM'
  where id = 'aley';
update public.branches set rehearsal_schedule = 'Mon · Tue · Wed — 6:00–9:00 PM'
  where id = 'chouf';
