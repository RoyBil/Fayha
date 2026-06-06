// Supabase Edge Function: sync_social
//
// Polls Instagram Graph API and Facebook Pages API for the choir's
// recent posts and upserts them into public.social_posts. New posts
// land as importance = 'normal' — editors then promote the ones the
// audience should see.
//
// Deploy:
//   supabase functions deploy sync_social
//
// Required secrets (set with `supabase secrets set …`):
//   IG_BUSINESS_ID         — your Instagram Business Account ID
//   IG_ACCESS_TOKEN        — long-lived IG access token
//   FB_PAGE_ID             — your Facebook Page ID
//   FB_ACCESS_TOKEN        — Page access token (long-lived)
//   SUPABASE_URL           — auto-set in Edge runtime
//   SUPABASE_SERVICE_ROLE_KEY — auto-set in Edge runtime
//
// Schedule with the Supabase Dashboard cron, e.g. every 30 minutes:
//   `*/30 * * * *  -> sync_social`

import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';

interface SocialRow {
  platform: 'Instagram' | 'Facebook';
  author: string;
  body: string;
  posted_label: string;
  posted_at: string;
  external_id: string;
  permalink: string | null;
  media_url: string | null;
  media_type: string | null;
  synced_at: string;
}

function ago(ts: string): string {
  const d = new Date(ts).getTime();
  const mins = Math.floor((Date.now() - d) / 60000);
  if (mins < 60) return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return `${Math.floor(mins / 1440)}d ago`;
}

async function fetchInstagram(): Promise<SocialRow[]> {
  const igId = Deno.env.get('IG_BUSINESS_ID');
  const token = Deno.env.get('IG_ACCESS_TOKEN');
  if (!igId || !token) return [];
  const fields =
    'id,caption,media_type,media_url,permalink,thumbnail_url,timestamp,username';
  const url =
    `https://graph.facebook.com/v19.0/${igId}/media` +
    `?fields=${fields}&limit=20&access_token=${token}`;
  const res = await fetch(url);
  if (!res.ok) {
    console.error('IG sync failed', res.status, await res.text());
    return [];
  }
  const json = await res.json();
  const now = new Date().toISOString();
  return (json.data ?? []).map((p: any) => ({
    platform: 'Instagram',
    author: `@${p.username ?? 'fayhanationalchoir'}`,
    body: p.caption ?? '',
    posted_label: ago(p.timestamp),
    posted_at: p.timestamp,
    external_id: p.id,
    permalink: p.permalink ?? null,
    media_url: p.media_url ?? p.thumbnail_url ?? null,
    media_type: (p.media_type ?? '').toLowerCase() || null,
    synced_at: now,
  }));
}

async function fetchFacebook(): Promise<SocialRow[]> {
  const pageId = Deno.env.get('FB_PAGE_ID');
  const token = Deno.env.get('FB_ACCESS_TOKEN');
  if (!pageId || !token) return [];
  const fields =
    'id,message,full_picture,permalink_url,created_time,from{name}';
  const url =
    `https://graph.facebook.com/v19.0/${pageId}/posts` +
    `?fields=${fields}&limit=20&access_token=${token}`;
  const res = await fetch(url);
  if (!res.ok) {
    console.error('FB sync failed', res.status, await res.text());
    return [];
  }
  const json = await res.json();
  const now = new Date().toISOString();
  return (json.data ?? []).map((p: any) => ({
    platform: 'Facebook',
    author: p.from?.name ?? 'Fayha National Choir',
    body: p.message ?? '',
    posted_label: ago(p.created_time),
    posted_at: p.created_time,
    external_id: p.id,
    permalink: p.permalink_url ?? null,
    media_url: p.full_picture ?? null,
    media_type: p.full_picture ? 'image' : null,
    synced_at: now,
  }));
}

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const [ig, fb] = await Promise.all([fetchInstagram(), fetchFacebook()]);
  const rows = [...ig, ...fb];
  if (rows.length === 0) {
    return new Response(
      JSON.stringify({ ok: true, synced: 0, note: 'No rows fetched' }),
      { headers: { 'content-type': 'application/json' } },
    );
  }

  // Upsert keyed on (platform, external_id). Existing rows keep their
  // editor-set `importance`; only the post body / media / timestamp
  // get refreshed.
  const { error } = await supabase
    .from('social_posts')
    .upsert(rows, { onConflict: 'platform,external_id' });

  if (error) {
    console.error('upsert failed', error);
    return new Response(
      JSON.stringify({ ok: false, error: error.message }),
      { status: 500, headers: { 'content-type': 'application/json' } },
    );
  }

  return new Response(
    JSON.stringify({ ok: true, synced: rows.length, ig: ig.length, fb: fb.length }),
    { headers: { 'content-type': 'application/json' } },
  );
});
