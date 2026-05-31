-- ============================================================
-- Fayha — Admins can manage songs & news
-- Run once in the Supabase SQL Editor, AFTER seed.sql + members.sql.
-- ============================================================

-- Admins / super admins can insert / update / delete songs.
drop policy if exists "admins manage songs" on public.songs;
create policy "admins manage songs" on public.songs
  for all
  using (public.my_role() in ('admin', 'superAdmin'))
  with check (public.my_role() in ('admin', 'superAdmin'));

-- Admins / super admins can insert / update / delete news posts.
drop policy if exists "admins manage news" on public.news_posts;
create policy "admins manage news" on public.news_posts
  for all
  using (public.my_role() in ('admin', 'superAdmin'))
  with check (public.my_role() in ('admin', 'superAdmin'));
