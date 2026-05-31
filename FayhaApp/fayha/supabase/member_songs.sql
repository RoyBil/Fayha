-- Songs each member knows. A member toggles a song as "memorized"
-- from the song detail screen — that adds/removes a row here.
-- Other members see the list on the member detail page.

create table if not exists public.member_songs (
  member_id uuid not null references public.members(id) on delete cascade,
  song_id   text not null references public.songs(id)   on delete cascade,
  added_at  timestamptz not null default now(),
  primary key (member_id, song_id)
);

create index if not exists member_songs_member_idx on public.member_songs(member_id);
create index if not exists member_songs_song_idx   on public.member_songs(song_id);

alter table public.member_songs enable row level security;

-- Every active member can see every other active member's songs.
drop policy if exists "member_songs_read" on public.member_songs;
create policy "member_songs_read" on public.member_songs
  for select using (public.my_status() = 'active');

-- You can add/remove your own rows.
drop policy if exists "member_songs_insert_own" on public.member_songs;
create policy "member_songs_insert_own" on public.member_songs
  for insert with check (member_id = auth.uid());

drop policy if exists "member_songs_delete_own" on public.member_songs;
create policy "member_songs_delete_own" on public.member_songs
  for delete using (member_id = auth.uid());
