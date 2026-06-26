-- ============================================================
-- Trip group document storage
-- Run once in the Supabase SQL editor.
-- ============================================================
-- Path layout inside the bucket:
--   info/{group_id}/{timestamp}.{ext}       ← admin-posted info attachments
--   {group_id}/{member_id}/{timestamp}.{ext} ← member-uploaded travel docs

-- 1. Create the bucket (public so getPublicUrl() works for attachment links).
insert into storage.buckets (id, name, public)
values ('trip_documents', 'trip_documents', true)
on conflict (id) do nothing;

-- 2. Storage RLS policies.

drop policy if exists "trip docs admin write"   on storage.objects;
drop policy if exists "trip docs member insert" on storage.objects;
drop policy if exists "trip docs member delete" on storage.objects;
drop policy if exists "trip docs public read"   on storage.objects;

-- Admins can do anything in this bucket (upload info files, delete any doc).
create policy "trip docs admin write" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'trip_documents'
    and public.is_trip_admin()
  )
  with check (
    bucket_id = 'trip_documents'
    and public.is_trip_admin()
  );

-- Members can upload their own documents.
-- Path format: {group_id}/{member_id}/{timestamp}.{ext}
-- We check that the second segment of the object name equals the caller's UID.
create policy "trip docs member insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'trip_documents'
    and split_part(name, '/', 2) = auth.uid()::text
  );

-- Members can delete files they uploaded (same path check).
create policy "trip docs member delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'trip_documents'
    and split_part(name, '/', 2) = auth.uid()::text
  );

-- Public bucket: explicit SELECT policy so reads work even if RLS config changes.
create policy "trip docs public read" on storage.objects
  for select using (bucket_id = 'trip_documents');
