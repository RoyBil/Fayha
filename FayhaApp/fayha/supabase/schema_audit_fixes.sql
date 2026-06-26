-- ============================================================
-- Schema audit fixes — run AFTER schema.sql and all patches.
-- Idempotent: safe to re-run.
-- ============================================================

-- 1. concerts.kind (no earlier migration added this column).
--    Values: 'concert' | 'rehearsal'
alter table public.concerts
  add column if not exists kind text not null default 'concert'
    check (kind in ('concert', 'rehearsal'));

-- ============================================================
-- Correct execution order for all patch files
-- (only run files that have NOT been run on the live project yet)
-- ============================================================
-- 1.  schema.sql                      ← canonical initial schema
-- 2.  singer_level.sql                ← members.singer_level column
-- 3.  choir_roles.sql                 ← updates singer_level check constraint
-- 4.  choir_songs.sql                 ← choir_songs table + choir_song_parts bucket
-- 5.  choir_songs_v2.sql              ← adds 9-voice-part columns
-- 6.  concert_posters.sql             ← concerts.poster_url + event_posters bucket
-- 7.  news_posters.sql                ← news_posts.poster_url (reuses event_posters)
-- 8.  social_feed.sql                 ← social_posts extra columns + RLS refresh
-- 9.  direct_messages.sql             ← direct_messages table (if not in schema)
-- 10. direct_messages_multi_admin.sql ← admin_id column + DM RLS refresh
-- 11. join_requests.sql               ← join_requests table + RLS
-- 12. trip_groups.sql                 ← trip tables + is_trip_admin() function
-- 13. member_notifications.sql        ← MUST run after trip_groups.sql (uses is_trip_admin)
-- 14. song_audio_bucket.sql           ← song_audio bucket + songs.audio_url column
-- 15. trip_documents_storage.sql      ← trip_documents bucket + storage policies
-- 16. schema_audit_fixes.sql          ← this file (concerts.kind + notes)
-- ============================================================

-- 2. RLS note: schema.sql creates policy "superadmin updates members" (superAdmin only).
--    The older members.sql creates "admins update members" (admin + superAdmin).
--    Whichever file was run LAST wins. On a fresh project (schema.sql only),
--    only superAdmin can update other members — which is the intended behaviour.
--    If "admins update members" is present on the live project you can clean it up:
--
--   drop policy if exists "admins update members" on public.members;
--
-- 3. The `live_location_enabled` column on members is referenced in app_state.dart
--    but may not exist on older project instances. Add it if missing:

alter table public.members
  add column if not exists live_location_enabled boolean not null default false;
