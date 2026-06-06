-- ============================================================
-- Fayha — Social feed from real Instagram + Facebook accounts.
-- Edge function `sync_social` writes rows here; editors moderate
-- importance; audience sees only the "important" ones.
-- ============================================================

alter table public.social_posts
  add column if not exists external_id    text,         -- IG / FB post id
  add column if not exists permalink      text,         -- canonical URL
  add column if not exists media_url      text,         -- image / video thumb
  add column if not exists media_type     text,         -- image | video | reel | carousel
  add column if not exists importance     text not null default 'normal',
                                                        -- important | normal | hidden
  add column if not exists synced_at      timestamptz;

-- Dedup key so the sync function can upsert safely.
create unique index if not exists social_posts_platform_external_idx
  on public.social_posts (platform, external_id)
  where external_id is not null;

-- ===== Reads =====
-- Audience (anon + authenticated) — only IMPORTANT posts surface.
drop policy if exists "Social posts are publicly readable" on public.social_posts;
drop policy if exists "Important social posts public" on public.social_posts;
create policy "Important social posts public" on public.social_posts
  for select using (importance = 'important');

-- Editors + super admins see everything (incl. hidden, normal).
drop policy if exists "Editors read all social posts" on public.social_posts;
create policy "Editors read all social posts" on public.social_posts
  for select to authenticated
  using (public.my_role() in ('editor', 'superAdmin'));

-- ===== Writes =====
-- Editors + super admins can update (importance) and delete.
drop policy if exists "Editors manage social posts" on public.social_posts;
create policy "Editors manage social posts" on public.social_posts
  for update to authenticated
  using (public.my_role() in ('editor', 'superAdmin'))
  with check (public.my_role() in ('editor', 'superAdmin'));

drop policy if exists "Editors delete social posts" on public.social_posts;
create policy "Editors delete social posts" on public.social_posts
  for delete to authenticated
  using (public.my_role() in ('editor', 'superAdmin'));

-- Inserts are done by the sync edge function using the service_role
-- key, which bypasses RLS, so no extra insert policy is needed.
