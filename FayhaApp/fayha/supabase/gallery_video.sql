-- Extends the members-only gallery to support video posts in addition
-- to photos. Run this after gallery.sql.

alter table public.gallery_posts
  add column if not exists media_type text not null default 'image';
-- media_type: 'image' | 'video'

-- Backfill old rows just in case.
update public.gallery_posts set media_type = 'image' where media_type is null;
