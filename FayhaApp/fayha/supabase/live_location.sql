-- Members can opt into sharing their LIVE phone location with the Maestro.
-- Once enabled, the app writes the member's coordinates here every ~30s
-- while the app is open. Only the Maestro (superAdmin) can read these
-- columns; the member can update their own row; nobody can turn it off
-- from the app (the only way to stop is to sign out / close the app or
-- have the Maestro flip the flag on their side).

alter table public.members
  add column if not exists live_location_enabled boolean not null default false;
alter table public.members
  add column if not exists live_lat   double precision;
alter table public.members
  add column if not exists live_lng   double precision;
alter table public.members
  add column if not exists live_at    timestamptz;

-- Members can already update their own row via the existing
-- "update own member row" policy. That covers writing the live coords.

-- Read access: a dedicated, narrow view that exposes only the live
-- columns. Open to every signed-in (authenticated) user.
create or replace view public.live_locations as
  select
    m.id,
    m.name,
    m.branch,
    m.voice_section,
    m.role,
    m.photo_url,
    m.live_lat,
    m.live_lng,
    m.live_at
  from public.members m
  where m.live_location_enabled = true
    and m.live_lat is not null
    and m.live_lng is not null;

grant select on public.live_locations to authenticated;
