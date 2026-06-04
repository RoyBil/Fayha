-- Extends testimonials with email, photo, and editor-managed importance.
-- Run this once in the Supabase SQL editor.

-- ===== Columns =====
alter table public.testimonials
  add column if not exists email text,
  add column if not exists photo_url text,
  add column if not exists importance text not null default 'normal';
-- importance: 'featured' | 'normal' | 'hidden'

-- Migrate old status values to importance.
update public.testimonials
   set importance = 'normal'
 where importance is null
    or (importance = 'normal' and status = 'approved');
update public.testimonials
   set importance = 'hidden'
 where status = 'rejected';
-- (leave 'pending' rows as 'normal' so editors can decide.)

-- ===== Read policy =====
-- Replace old "approved only" with "featured or normal".
drop policy if exists "Approved testimonials are publicly readable" on public.testimonials;
drop policy if exists "Public testimonials are readable" on public.testimonials;
create policy "Public testimonials are readable" on public.testimonials
  for select using (importance in ('featured', 'normal'));

-- Editors and super admins see everything (including hidden).
drop policy if exists "Editors read all testimonials" on public.testimonials;
create policy "Editors read all testimonials" on public.testimonials
  for select to authenticated
  using (public.my_role() in ('editor', 'superAdmin'));

-- ===== Write policies =====
-- Anyone can still submit (audience form).
drop policy if exists "Anyone can submit a testimonial" on public.testimonials;
create policy "Anyone can submit a testimonial" on public.testimonials
  for insert with check (true);

-- Editors + super admins can update importance / delete.
drop policy if exists "Editors manage testimonials" on public.testimonials;
create policy "Editors manage testimonials" on public.testimonials
  for update to authenticated
  using (public.my_role() in ('editor', 'superAdmin'))
  with check (public.my_role() in ('editor', 'superAdmin'));

drop policy if exists "Editors delete testimonials" on public.testimonials;
create policy "Editors delete testimonials" on public.testimonials
  for delete to authenticated
  using (public.my_role() in ('editor', 'superAdmin'));

-- ===== Photo storage bucket =====
insert into storage.buckets (id, name, public)
values ('testimonial_photos', 'testimonial_photos', true)
on conflict (id) do nothing;

-- Anyone can read (public bucket).
drop policy if exists "testimonial photos read all" on storage.objects;
create policy "testimonial photos read all" on storage.objects
  for select using (bucket_id = 'testimonial_photos');

-- Anyone (incl. anon audience) can upload their own testimonial photo.
drop policy if exists "testimonial photos upload anyone" on storage.objects;
create policy "testimonial photos upload anyone" on storage.objects
  for insert
  with check (bucket_id = 'testimonial_photos');

-- Editors + super admins can update / delete photos (cleanup).
drop policy if exists "testimonial photos manage editor" on storage.objects;
create policy "testimonial photos manage editor" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'testimonial_photos'
    and public.my_role() in ('editor', 'superAdmin')
  );

-- ===== Re-assert editor policies on event_posters (idempotent) =====
-- If editor_role.sql hasn't been applied, this fixes the
-- "StorageException" editors hit when uploading an event poster.
insert into storage.buckets (id, name, public)
values ('event_posters', 'event_posters', true)
on conflict (id) do nothing;

drop policy if exists "posters upload admin"  on storage.objects;
drop policy if exists "posters update admin"  on storage.objects;
drop policy if exists "posters upload editor" on storage.objects;
drop policy if exists "posters update editor" on storage.objects;
drop policy if exists "posters delete editor" on storage.objects;

create policy "posters upload editor" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'event_posters'
    and public.my_role() in ('editor', 'superAdmin')
  );

create policy "posters update editor" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'event_posters'
    and public.my_role() in ('editor', 'superAdmin')
  );

create policy "posters delete editor" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'event_posters'
    and public.my_role() in ('editor', 'superAdmin')
  );
