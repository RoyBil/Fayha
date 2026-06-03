-- Every audience-facing reference list (news_posts, trained_choirs,
-- venues, achievements, social_projects, songs, branches) was seeded
-- twice — once by schema.sql and once by seed.sql, neither of which
-- had `on conflict do nothing` on the older inserts. This script
-- deletes the duplicate rows, keeping the OLDEST one of each.
--
-- Safe to re-run: if there are no duplicates left, it's a no-op.

-- Helper: delete every row that shares the same "natural key" with an
-- older row of the same table. We compare against a tuple of fields
-- that uniquely identifies an entry semantically.

-- ===== news_posts (title + date_label) =====
delete from public.news_posts a
using public.news_posts b
where a.ctid <> b.ctid
  and a.title = b.title
  and coalesce(a.date_label, '') = coalesce(b.date_label, '')
  and a.created_at > b.created_at;

-- ===== trained_choirs (name + period) =====
delete from public.trained_choirs a
using public.trained_choirs b
where a.ctid <> b.ctid
  and a.name = b.name
  and coalesce(a.period, '') = coalesce(b.period, '')
  and a.ctid > b.ctid;

-- ===== venues (city + country + performed_at) =====
delete from public.venues a
using public.venues b
where a.ctid <> b.ctid
  and a.city = b.city
  and coalesce(a.country, '') = coalesce(b.country, '')
  and coalesce(a.performed_at::text, '') = coalesce(b.performed_at::text, '')
  and a.ctid > b.ctid;

-- ===== achievements (title) =====
delete from public.achievements a
using public.achievements b
where a.ctid <> b.ctid
  and a.title = b.title
  and a.ctid > b.ctid;

-- ===== social_projects (title) =====
delete from public.social_projects a
using public.social_projects b
where a.ctid <> b.ctid
  and a.title = b.title
  and a.ctid > b.ctid;
