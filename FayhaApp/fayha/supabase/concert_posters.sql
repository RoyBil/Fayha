-- Adds an optional poster image to each concert / big-rehearsal event.
-- Admin uploads it from the "Add Event" form; audience members see
-- it big at the top of the event detail screen.

alter table public.concerts
  add column if not exists poster_url text;

-- Public bucket for the posters (anyone can view; only admins write).
insert into storage.buckets (id, name, public)
values ('event_posters', 'event_posters', true)
on conflict (id) do nothing;

drop policy if exists "posters upload admin" on storage.objects;
create policy "posters upload admin" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'event_posters'
    and public.my_role() in ('admin', 'superAdmin')
  );

drop policy if exists "posters update admin" on storage.objects;
create policy "posters update admin" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'event_posters'
    and public.my_role() in ('admin', 'superAdmin')
  );

drop policy if exists "posters read all" on storage.objects;
create policy "posters read all" on storage.objects
  for select
  using (bucket_id = 'event_posters');
