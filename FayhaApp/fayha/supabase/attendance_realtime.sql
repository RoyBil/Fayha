-- Publishes the attendance + rehearsals tables to Supabase realtime,
-- so members can see their stats update live when an admin marks
-- them present from another device.

alter publication supabase_realtime add table public.attendance;
alter publication supabase_realtime add table public.rehearsals;
