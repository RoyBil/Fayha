-- Songs for the choir's internal library (members + admins + Maestro).
-- Separate from `public.songs` which stays for the public audience page.
-- Each choir song REQUIRES audio uploads for all 8 voice sections:
--   Sopranos: S1, S2 · Altos: A1, A2 · Tenors: T1, T2 · Basses: B1, B2

create table if not exists public.choir_songs (
  id           text primary key,
  title        text not null,
  subtitle     text,
  composers    text,
  description  text,
  lyrics       text,
  youtube_url  text,
  sort_order   int  default 0,

  -- One audio file per voice section. All required.
  soprano1_url text not null,
  soprano2_url text not null,
  alto1_url    text not null,
  alto2_url    text not null,
  tenor1_url   text not null,
  tenor2_url   text not null,
  bass1_url    text not null,
  bass2_url    text not null,

  created_by   uuid references public.members(id) on delete set null,
  created_at   timestamptz not null default now()
);

create index if not exists choir_songs_sort_idx on public.choir_songs(sort_order);

alter table public.choir_songs enable row level security;

-- Read: any active member (i.e. signed-in choir person).
drop policy if exists "choir_songs_read" on public.choir_songs;
create policy "choir_songs_read" on public.choir_songs
  for select using (public.my_status() = 'active');

-- Write: admins + superAdmin.
drop policy if exists "choir_songs_write" on public.choir_songs;
create policy "choir_songs_write" on public.choir_songs
  for all using (public.my_role() in ('admin','superAdmin'))
  with check (public.my_role() in ('admin','superAdmin'));

-- =====  Storage bucket for the audio parts  =====
insert into storage.buckets (id, name, public)
values ('choir_song_parts', 'choir_song_parts', true)
on conflict (id) do nothing;

-- Path layout: {song_id}/{voice_part}.m4a   e.g. song_123/s1.m4a
-- Only admins/superAdmins can upload. Any signed-in member can read.

drop policy if exists "choir parts upload admin" on storage.objects;
create policy "choir parts upload admin" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'choir_song_parts'
    and public.my_role() in ('admin','superAdmin')
  );

drop policy if exists "choir parts update admin" on storage.objects;
create policy "choir parts update admin" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'choir_song_parts'
    and public.my_role() in ('admin','superAdmin')
  );

drop policy if exists "choir parts delete admin" on storage.objects;
create policy "choir parts delete admin" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'choir_song_parts'
    and public.my_role() in ('admin','superAdmin')
  );

drop policy if exists "choir parts read members" on storage.objects;
create policy "choir parts read members" on storage.objects
  for select to authenticated
  using (bucket_id = 'choir_song_parts');

-- =====  Re-point member_songs at choir_songs  =====
-- (was pointing at public.songs — the audience table)
alter table public.member_songs
  drop constraint if exists member_songs_song_id_fkey;

-- Clear any leftover rows that referenced the old `songs` IDs and
-- don't exist in choir_songs (safe to truncate; it's a per-user list).
delete from public.member_songs
  where song_id not in (select id from public.choir_songs);

alter table public.member_songs
  add constraint member_songs_song_id_fkey
  foreign key (song_id) references public.choir_songs(id) on delete cascade;
