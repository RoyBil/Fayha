-- Introduces a new 'editor' role: members appointed by Maestro to post
-- news, events, and announcements. Admins (branch admins) lose that
-- ability — they keep attendance + member management.
--
-- Allowed role values now: 'member' | 'admin' | 'editor' | 'superAdmin'

-- Update write policies on each content table to require editor or
-- super admin. (Reads stay public / unchanged.)

-- ===== News posts =====
drop policy if exists "admins manage news" on public.news_posts;
drop policy if exists "editors manage news" on public.news_posts;
create policy "editors manage news" on public.news_posts
  for all using (public.my_role() in ('editor', 'superAdmin'))
  with check (public.my_role() in ('editor', 'superAdmin'));

-- ===== Concerts / events =====
drop policy if exists "admins manage concerts" on public.concerts;
drop policy if exists "editors manage concerts" on public.concerts;
create policy "editors manage concerts" on public.concerts
  for all using (public.my_role() in ('editor', 'superAdmin'))
  with check (public.my_role() in ('editor', 'superAdmin'));

-- ===== Announcements (messages) =====
drop policy if exists "admins manage messages" on public.messages;
drop policy if exists "admins send messages" on public.messages;
drop policy if exists "editors manage messages" on public.messages;
create policy "editors manage messages" on public.messages
  for insert with check (public.my_role() in ('editor', 'superAdmin'));
create policy "editors delete messages" on public.messages
  for delete using (public.my_role() in ('editor', 'superAdmin'));

-- (We leave the existing select-side / "members read messages" policy
-- alone — reading isn't restricted.)

-- Note: songs stay writable by 'admin' (admin still adds songs).
-- If you want only editors to add songs too, run:
-- drop policy if exists "admins manage songs" on public.songs;
-- create policy "editors manage songs" on public.songs
--   for all using (public.my_role() in ('editor', 'superAdmin'))
--   with check (public.my_role() in ('editor', 'superAdmin'));

-- ===== Storage: event_posters bucket =====
-- The bucket lives in storage.objects and was previously restricted
-- to admin/superAdmin. Update to allow editor + superAdmin so editors
-- can actually upload posters when creating news/events.

drop policy if exists "posters upload admin" on storage.objects;
drop policy if exists "posters upload editor" on storage.objects;
create policy "posters upload editor" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'event_posters'
    and public.my_role() in ('editor', 'superAdmin')
  );

drop policy if exists "posters update admin" on storage.objects;
drop policy if exists "posters update editor" on storage.objects;
create policy "posters update editor" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'event_posters'
    and public.my_role() in ('editor', 'superAdmin')
  );

drop policy if exists "posters delete editor" on storage.objects;
create policy "posters delete editor" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'event_posters'
    and public.my_role() in ('editor', 'superAdmin')
  );

-- (Read policy "posters read all" stays as-is — posters are public.)
