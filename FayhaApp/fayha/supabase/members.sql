-- ============================================================
-- Fayha National Choir — Members & Auth
-- Run this once in the Supabase SQL Editor.
-- Also: Authentication → Providers → Email → turn OFF "Confirm email"
--       (so sign-up logs the user in immediately).
-- ============================================================

create table if not exists public.members (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  phone text,
  photo_url text,
  branch text not null default 'Tripoli',
  voice_section text not null default 'Soprano',
  role text not null default 'member',      -- member | admin | superAdmin
  status text not null default 'pending',   -- pending | active | deactivated | left
  join_date date default current_date,
  favorite_song_id text,
  least_favorite_song_id text,
  share_location boolean default true,
  created_at timestamptz default now()
);

alter table public.members enable row level security;

-- Helper functions (security definer = no RLS recursion)
create or replace function public.my_role()
returns text language sql security definer stable
as $$ select role from public.members where id = auth.uid() $$;

create or replace function public.my_status()
returns text language sql security definer stable
as $$ select status from public.members where id = auth.uid() $$;

-- RLS policies
drop policy if exists "read own member row" on public.members;
create policy "read own member row" on public.members
  for select using (auth.uid() = id);

drop policy if exists "admins read all members" on public.members;
create policy "admins read all members" on public.members
  for select using (public.my_role() in ('admin', 'superAdmin'));

drop policy if exists "update own member row" on public.members;
create policy "update own member row" on public.members
  for update using (auth.uid() = id);

drop policy if exists "admins update members" on public.members;
create policy "admins update members" on public.members
  for update using (public.my_role() in ('admin', 'superAdmin'));

-- Auto-create a members row whenever an auth user signs up.
-- Maestro's email is bootstrapped as superAdmin + active.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
as $$
begin
  insert into public.members (id, name, email, phone, branch, voice_section, role, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'New Member'),
    new.email,
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'branch', 'Tripoli'),
    coalesce(new.raw_user_meta_data->>'voice_section', 'Soprano'),
    case when new.email = 'maestro@fayhanationalchoir.com'
         then 'superAdmin' else 'member' end,
    case when new.email = 'maestro@fayhanationalchoir.com'
         then 'active' else 'pending' end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
