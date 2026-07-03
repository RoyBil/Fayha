-- =============================================================
-- Push notification infrastructure
-- Run this migration once against your Supabase project.
-- =============================================================

-- 1. Add fcm_token column so the app can store each member's FCM token.
ALTER TABLE members ADD COLUMN IF NOT EXISTS fcm_token text;

-- Members can only write their own token; admins can read all tokens
-- (needed by the edge function which runs under service-role key).
COMMENT ON COLUMN members.fcm_token IS
  'Firebase Cloud Messaging device token — stored by the Flutter app on login, cleared on logout.';

-- 2. Helper: invoke the send-push edge function via pg_net.
--    Requires the pg_net extension (enabled by default on Supabase).
--    Replace <YOUR_PROJECT_REF> with your Supabase project ref.
CREATE OR REPLACE FUNCTION _notify_push(
  p_title      text,
  p_body       text,
  p_kind       text     DEFAULT 'announcement',
  p_source_id  text     DEFAULT NULL,
  p_member_ids uuid[]   DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url  text := 'https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/send-push';
  v_key  text := current_setting('app.service_role_key', true);
  v_body jsonb;
BEGIN
  v_body := jsonb_build_object(
    'title',  p_title,
    'body',   p_body,
    'kind',   p_kind
  );
  IF p_source_id IS NOT NULL THEN
    v_body := v_body || jsonb_build_object('source_id', p_source_id);
  END IF;
  IF p_member_ids IS NOT NULL THEN
    v_body := v_body || jsonb_build_object('member_ids', to_jsonb(p_member_ids));
  END IF;

  -- pg_net fire-and-forget (non-blocking).
  PERFORM net.http_post(
    url     := v_url,
    body    := v_body,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    )
  );
EXCEPTION WHEN OTHERS THEN
  -- Never let a push failure abort the main transaction.
  RAISE WARNING '[push] _notify_push failed: %', SQLERRM;
END;
$$;

-- NOTE: to activate the triggers below you must first set the
-- service-role key so the helper can authenticate with the edge function:
--   ALTER DATABASE postgres
--     SET app.service_role_key = '<your service_role key>';
-- Then reload the config in each session:  SELECT pg_reload_conf();

-- =============================================================
-- 3. Per-table triggers
-- =============================================================

-- ── Messages (announcements) ──────────────────────────────────
CREATE OR REPLACE FUNCTION _push_on_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _notify_push(NEW.title, NEW.body, 'announcement', NEW.id::text);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS push_on_message ON messages;
CREATE TRIGGER push_on_message
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION _push_on_message();

-- ── News posts ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _push_on_news()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _notify_push(
    NEW.title,
    COALESCE(LEFT(NEW.body, 120), 'Tap to read the full article.'),
    'news',
    NEW.id::text
  );
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS push_on_news ON news_posts;
CREATE TRIGGER push_on_news
  AFTER INSERT ON news_posts
  FOR EACH ROW EXECUTE FUNCTION _push_on_news();

-- ── Concerts / rehearsals ─────────────────────────────────────
CREATE OR REPLACE FUNCTION _push_on_concert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_label text := CASE WHEN NEW.kind = 'rehearsal' THEN 'Rehearsal' ELSE 'Concert' END;
BEGIN
  PERFORM _notify_push(
    v_label || ': ' || NEW.title,
    NEW.location || ' — ' || to_char(NEW.starts_at AT TIME ZONE 'UTC', 'DD Mon YYYY'),
    'concert',
    NEW.id::text
  );
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS push_on_concert ON concerts;
CREATE TRIGGER push_on_concert
  AFTER INSERT ON concerts
  FOR EACH ROW EXECUTE FUNCTION _push_on_concert();

-- ── Polls ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _push_on_poll()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _notify_push(
    'New poll: ' || NEW.question,
    'From ' || COALESCE(NEW.created_by_name, 'an admin') || ' — tap to vote.',
    'poll',
    NEW.id::text
  );
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS push_on_poll ON polls;
CREATE TRIGGER push_on_poll
  AFTER INSERT ON polls
  FOR EACH ROW EXECUTE FUNCTION _push_on_poll();

-- ── Gallery posts ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _push_on_gallery()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _notify_push(
    'New Gallery Post',
    COALESCE(NULLIF(NEW.caption, ''), NEW.category, 'Check out the latest photo.'),
    'gallery',
    NEW.id::text
  );
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS push_on_gallery ON gallery_posts;
CREATE TRIGGER push_on_gallery
  AFTER INSERT ON gallery_posts
  FOR EACH ROW EXECUTE FUNCTION _push_on_gallery();

-- ── Trip groups (new group created) ──────────────────────────
CREATE OR REPLACE FUNCTION _push_on_trip_group()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _notify_push(
    'New Trip: ' || NEW.name,
    COALESCE('Destination: ' || NEW.destination, 'A new trip group has been created.'),
    'trip',
    NEW.id::text
  );
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS push_on_trip_group ON trip_groups;
CREATE TRIGGER push_on_trip_group
  AFTER INSERT ON trip_groups
  FOR EACH ROW EXECUTE FUNCTION _push_on_trip_group();

-- ── Member notifications (trip added, etc.) ───────────────────
--    These are personal, so only the target member receives the push.
CREATE OR REPLACE FUNCTION _push_on_member_notif()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _notify_push(
    NEW.title,
    NEW.body,
    NEW.kind,
    NEW.source_id::text,
    ARRAY[NEW.member_id]
  );
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS push_on_member_notif ON member_notifications;
CREATE TRIGGER push_on_member_notif
  AFTER INSERT ON member_notifications
  FOR EACH ROW EXECUTE FUNCTION _push_on_member_notif();
