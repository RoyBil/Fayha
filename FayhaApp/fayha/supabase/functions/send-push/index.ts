/**
 * send-push — Supabase Edge Function
 *
 * Sends FCM v1 push notifications to one or more members.
 *
 * SETUP:
 *   1. In Firebase console → Project Settings → Service Accounts →
 *      Generate new private key.  Save the JSON file.
 *   2. In Supabase Dashboard → Edge Functions → Secrets, add:
 *        FIREBASE_SERVICE_ACCOUNT = <paste the entire JSON string>
 *   3. Deploy:  supabase functions deploy send-push --no-verify-jwt
 *
 * REQUEST BODY (JSON):
 *   {
 *     title:       string,
 *     body:        string,
 *     kind?:       string,   // e.g. 'announcement' | 'poll' | 'gallery' …
 *     source_id?:  string,
 *     member_ids?: string[]  // omit to broadcast to all active members
 *   }
 *
 * RESPONSE (JSON):
 *   { sent: number, failed: number, skipped: number }
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Firebase service account loaded from Supabase secret.
const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}';
let serviceAccount: Record<string, string> = {};
try {
  serviceAccount = JSON.parse(serviceAccountRaw);
} catch {
  console.error('[send-push] FIREBASE_SERVICE_ACCOUNT is not valid JSON');
}
const PROJECT_ID = serviceAccount['project_id'] ?? '';

// ── OAuth2 access-token from service account ──────────────────────────────

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: serviceAccount['client_email'],
    sub: serviceAccount['client_email'],
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  };

  const b64url = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');

  const header = b64url({ alg: 'RS256', typ: 'JWT' });
  const payload = b64url(claim);
  const sigInput = `${header}.${payload}`;

  const pemKey = (serviceAccount['private_key'] ?? '').replace(/\\n/g, '\n');
  const keyBody = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(keyBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(sigInput),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${sigInput}.${sigB64}`;

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data = await resp.json() as { access_token: string };
  return data.access_token;
}

// ── Send one FCM message ──────────────────────────────────────────────────

async function sendOne(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
): Promise<boolean> {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: 'high',
            notification: {
              channel_id: 'fayha_v2',
              default_sound: true,
              notification_priority: 'PRIORITY_HIGH',
              visibility: 'PUBLIC',
            },
          },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        },
      }),
    },
  );
  if (!resp.ok) {
    const err = await resp.text();
    // Token no longer valid — caller should clean it up.
    if (err.includes('UNREGISTERED') || err.includes('INVALID_ARGUMENT')) {
      console.warn('[send-push] Stale token, skipping:', token.slice(-8));
    } else {
      console.error('[send-push] FCM error:', err);
    }
    return false;
  }
  return true;
}

// ── Handler ───────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  if (!PROJECT_ID) {
    return new Response(
      JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT not configured' }),
      { status: 503, headers: { 'Content-Type': 'application/json' } },
    );
  }

  let title: string, body: string, kind: string,
    sourceId: string | undefined, memberIds: string[] | undefined;

  try {
    const payload = await req.json() as {
      title: string;
      body: string;
      kind?: string;
      source_id?: string;
      member_ids?: string[];
    };
    title = payload.title;
    body = payload.body;
    kind = payload.kind ?? 'announcement';
    sourceId = payload.source_id;
    memberIds = payload.member_ids;

    if (!title || !body) throw new Error('title and body are required');
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Fetch FCM tokens for target members.
  let query = supabase
    .from('members')
    .select('id, fcm_token')
    .eq('status', 'active')
    .not('fcm_token', 'is', null);

  if (memberIds && memberIds.length > 0) {
    query = query.in('id', memberIds);
  }

  const { data: members, error } = await query;
  if (error) {
    console.error('[send-push] DB error:', error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (!members || members.length === 0) {
    return new Response(JSON.stringify({ sent: 0, failed: 0, skipped: 0 }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken();
  } catch (e) {
    console.error('[send-push] OAuth error:', e);
    return new Response(JSON.stringify({ error: 'OAuth token failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const data: Record<string, string> = {
    kind,
    source_id: sourceId ?? '',
  };

  let sent = 0, failed = 0, skipped = 0;
  const staleTokenIds: string[] = [];

  for (const m of members) {
    if (!m.fcm_token) { skipped++; continue; }
    const ok = await sendOne(m.fcm_token, title, body, data, accessToken);
    if (ok) {
      sent++;
    } else {
      failed++;
      staleTokenIds.push(m.id);
    }
  }

  // Clear stale tokens in the background so future dispatches skip them.
  if (staleTokenIds.length > 0) {
    supabase
      .from('members')
      .update({ fcm_token: null })
      .in('id', staleTokenIds)
      .then(() => {})
      .catch(console.error);
  }

  console.log(`[send-push] sent=${sent} failed=${failed} skipped=${skipped}`);
  return new Response(JSON.stringify({ sent, failed, skipped }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
