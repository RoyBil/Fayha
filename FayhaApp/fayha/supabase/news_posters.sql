-- Adds optional poster image to news posts. The same `event_posters`
-- storage bucket is reused (also public, admin-write).

alter table public.news_posts
  add column if not exists poster_url text;

-- If you haven't created the event_posters bucket yet, also run:
--   supabase/concert_posters.sql
-- which creates the bucket + write policies. News uses the same one.
