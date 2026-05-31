-- Add house location columns to members. Members set their own house
-- via the profile screen; admins (and Maestro) can see all houses on the map.

alter table public.members
  add column if not exists house_lat double precision;

alter table public.members
  add column if not exists house_lng double precision;

alter table public.members
  add column if not exists house_address text;
