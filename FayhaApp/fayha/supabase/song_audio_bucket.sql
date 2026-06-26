-- ============================================================
-- Audience song audio files
-- Run once in the Supabase SQL editor.
-- ============================================================

-- 1. Storage bucket (public so getPublicUrl() works in the audience app).
insert into storage.buckets (id, name, public)
values ('song_audio', 'song_audio', true)
on conflict (id) do nothing;

-- 2. audio_url column on the songs table (may already exist on the live project).
alter table public.songs
  add column if not exists audio_url text;

-- 3. Storage RLS policies.
--    Only admins/superAdmins may upload or delete; everyone (including anon) may read.

drop policy if exists "song audio upload admin"  on storage.objects;
drop policy if exists "song audio update admin"  on storage.objects;
drop policy if exists "song audio delete admin"  on storage.objects;
drop policy if exists "song audio public read"   on storage.objects;

create policy "song audio upload admin" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'song_audio'
    and public.my_role() in ('admin', 'superAdmin')
  );

create policy "song audio update admin" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'song_audio'
    and public.my_role() in ('admin', 'superAdmin')
  );

create policy "song audio delete admin" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'song_audio'
    and public.my_role() in ('admin', 'superAdmin')
  );

-- Public bucket → reads are unrestricted, but an explicit SELECT policy
-- keeps things consistent when RLS is forced by a future config change.
create policy "song audio public read" on storage.objects
  for select using (bucket_id = 'song_audio');
