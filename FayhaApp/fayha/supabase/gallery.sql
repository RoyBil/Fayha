-- Members-only gallery: editors + super admins post; every signed-in
-- member can browse. Audience (anon) is excluded.

create table if not exists public.gallery_posts (
  id          uuid primary key default gen_random_uuid(),
  photo_url   text not null,
  caption     text,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

create index if not exists gallery_posts_created_at_idx
  on public.gallery_posts (created_at desc);

alter table public.gallery_posts enable row level security;

-- Any authenticated member can read.
drop policy if exists "Members read gallery" on public.gallery_posts;
create policy "Members read gallery" on public.gallery_posts
  for select to authenticated using (true);

-- Editors + super admins can insert / update / delete.
drop policy if exists "Editors manage gallery" on public.gallery_posts;
create policy "Editors manage gallery" on public.gallery_posts
  for all to authenticated
  using (public.my_role() in ('editor', 'superAdmin'))
  with check (public.my_role() in ('editor', 'superAdmin'));

-- ===== Storage: gallery_photos bucket =====
-- Public bucket so the in-app image widget can load via getPublicUrl.
-- The audience never sees the URLs because the table itself is hidden
-- from anon users.
insert into storage.buckets (id, name, public)
values ('gallery_photos', 'gallery_photos', true)
on conflict (id) do nothing;

drop policy if exists "gallery photos read all" on storage.objects;
create policy "gallery photos read all" on storage.objects
  for select using (bucket_id = 'gallery_photos');

drop policy if exists "gallery photos upload editor" on storage.objects;
create policy "gallery photos upload editor" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'gallery_photos'
    and public.my_role() in ('editor', 'superAdmin')
  );

drop policy if exists "gallery photos delete editor" on storage.objects;
create policy "gallery photos delete editor" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'gallery_photos'
    and public.my_role() in ('editor', 'superAdmin')
  );
