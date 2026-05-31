-- Voice messages live alongside text in `direct_messages`.
-- A message can be text only, audio only, or both.

alter table public.direct_messages
  add column if not exists audio_url text;

alter table public.direct_messages
  add column if not exists audio_duration_ms int;

-- Allow body to be nullable so we can send voice-only messages.
alter table public.direct_messages
  alter column body drop not null;

-- =====  Storage bucket  =====
-- Create the bucket from the Supabase dashboard:
--   Storage → New bucket → name: voice_messages  (Public)
-- Or via SQL:
insert into storage.buckets (id, name, public)
values ('voice_messages', 'voice_messages', true)
on conflict (id) do nothing;

-- =====  Storage policies  =====
-- Path layout: {memberId}/{epochMs}.m4a
-- Each member (and Maestro) can upload into their own folder.

drop policy if exists "voice upload own" on storage.objects;
create policy "voice upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'voice_messages'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "voice update own" on storage.objects;
create policy "voice update own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'voice_messages'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "voice read all" on storage.objects;
create policy "voice read all" on storage.objects
  for select to authenticated
  using (bucket_id = 'voice_messages');
