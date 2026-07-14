-- =============================================================
-- Run this once in the Supabase SQL editor (Dashboard → SQL Editor)
-- =============================================================

-- ── 1. Fix "A cappella" misspellings in live data ─────────────

UPDATE public.choir_songs
SET
  title       = REGEXP_REPLACE(title,       'acappell[ao]|acapell[ao]', 'A cappella', 'gi'),
  subtitle    = REGEXP_REPLACE(subtitle,    'acappell[ao]|acapell[ao]', 'A cappella', 'gi'),
  description = REGEXP_REPLACE(description, 'acappell[ao]|acapell[ao]', 'A cappella', 'gi'),
  lyrics      = REGEXP_REPLACE(lyrics,      'acappell[ao]|acapell[ao]', 'A cappella', 'gi')
WHERE
  title       ~* 'acapell|acappell'
  OR subtitle ~* 'acapell|acappell'
  OR description ~* 'acapell|acappell'
  OR lyrics   ~* 'acapell|acappell';

UPDATE public.songs
SET
  title       = REGEXP_REPLACE(title,       'acappell[ao]|acapell[ao]', 'A cappella', 'gi'),
  subtitle    = REGEXP_REPLACE(subtitle,    'acappell[ao]|acapell[ao]', 'A cappella', 'gi'),
  description = REGEXP_REPLACE(description, 'acappell[ao]|acapell[ao]', 'A cappella', 'gi'),
  lyrics      = REGEXP_REPLACE(lyrics,      'acappell[ao]|acapell[ao]', 'A cappella', 'gi')
WHERE
  title       ~* 'acapell|acappell'
  OR subtitle ~* 'acapell|acappell'
  OR description ~* 'acapell|acappell'
  OR lyrics   ~* 'acapell|acappell';

-- Verify — should return 0 rows:
-- SELECT id, title FROM choir_songs WHERE title ~* 'acapell|acappell';
-- SELECT id, title FROM songs        WHERE title ~* 'acapell|acappell';


-- ── 2. Activate the DB-side push trigger ──────────────────────
--    Replace YOUR_PROJECT_REF and YOUR_SERVICE_ROLE_KEY below,
--    then run this entire block.
--
--    Find them in: Supabase Dashboard → Project Settings → API
--      • Project URL  →  https://YOUR_PROJECT_REF.supabase.co
--      • service_role key  (the long secret key, NOT the anon key)

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
  v_url  text := 'https://ovwvqtppgugzeumttrjr.supabase.co/functions/v1/send-push';
  v_key  text := 'YOUR_SERVICE_ROLE_KEY';
  v_body jsonb;
BEGIN
  IF v_url LIKE '%YOUR_PROJECT_REF%' OR v_key = 'YOUR_SERVICE_ROLE_KEY' THEN
    RAISE WARNING '[push] _notify_push: placeholders not replaced — skipping push';
    RETURN;
  END IF;

  v_body := jsonb_build_object(
    'title', p_title,
    'body',  p_body,
    'kind',  p_kind
  );
  IF p_source_id IS NOT NULL THEN
    v_body := v_body || jsonb_build_object('source_id', p_source_id);
  END IF;
  IF p_member_ids IS NOT NULL THEN
    v_body := v_body || jsonb_build_object('member_ids', to_jsonb(p_member_ids));
  END IF;

  PERFORM net.http_post(
    url     := v_url,
    body    := v_body,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    )
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING '[push] _notify_push failed: %', SQLERRM;
END;
$$;


-- ── 3. Firebase service account secret ────────────────────────
--    Go to:  Supabase Dashboard → Edge Functions → send-push → Secrets
--    Add:    Name = FIREBASE_SERVICE_ACCOUNT
--            Value = <paste the entire JSON file from Firebase>
--
--    Get the JSON:
--      Firebase Console → Project Settings → Service Accounts
--        → Generate new private key → download → paste entire file content
