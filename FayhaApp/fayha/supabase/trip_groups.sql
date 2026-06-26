-- ============================================================
-- Trip Groups
-- Admins create named trip groups (e.g. "Barcelona Trip"),
-- assign specific members, share trip information by category,
-- and members upload their own documents (passport, visa, etc.).
-- ============================================================

-- Core group record
create table if not exists public.trip_groups (
  id           uuid        primary key default gen_random_uuid(),
  name         text        not null,
  description  text,
  destination  text,
  departure_date date,
  return_date    date,
  created_by   uuid        references public.members(id),
  created_at   timestamptz not null default now()
);

-- Which members belong to each group
create table if not exists public.trip_group_members (
  group_id   uuid not null references public.trip_groups(id) on delete cascade,
  member_id  uuid not null references public.members(id)     on delete cascade,
  added_at   timestamptz not null default now(),
  primary key (group_id, member_id)
);

-- Trip information posted by admins (visa requirements, tickets,
-- hotel details, schedules, general announcements)
create table if not exists public.trip_group_info (
  id          uuid        primary key default gen_random_uuid(),
  group_id    uuid        not null references public.trip_groups(id) on delete cascade,
  category    text        not null check (category in
                ('announcement', 'visa', 'tickets', 'hotel', 'schedule', 'other')),
  title       text        not null,
  body        text,
  file_url    text,
  file_name   text,
  created_by  uuid        references public.members(id),
  created_at  timestamptz not null default now()
);

-- Documents uploaded by members (passport, visa copy, insurance, etc.)
create table if not exists public.trip_group_documents (
  id            uuid        primary key default gen_random_uuid(),
  group_id      uuid        not null references public.trip_groups(id) on delete cascade,
  member_id     uuid        not null references public.members(id),
  document_type text        not null check (document_type in
                  ('passport', 'visa', 'insurance', 'other')),
  file_name     text        not null,
  file_url      text        not null,
  uploaded_at   timestamptz not null default now()
);

-- ============================================================
-- Row-level security
-- ============================================================

alter table public.trip_groups         enable row level security;
alter table public.trip_group_members  enable row level security;
alter table public.trip_group_info     enable row level security;
alter table public.trip_group_documents enable row level security;

-- Helper: is the caller an admin or super admin?
create or replace function public.is_trip_admin()
returns boolean language sql security definer as $$
  select exists (
    select 1 from public.members
    where id = auth.uid() and role in ('admin', 'superAdmin')
  );
$$;

-- Helper: returns every trip_group_id the current user is a member of.
-- SECURITY DEFINER bypasses RLS on trip_group_members so member-facing
-- policies can call this without triggering infinite recursion (42P17).
create or replace function public.my_trip_group_ids()
returns setof uuid language sql security definer stable as $$
  select group_id from public.trip_group_members
  where member_id = auth.uid()
$$;

-- ---- trip_groups ----
drop policy if exists "Admins manage trip groups"    on public.trip_groups;
drop policy if exists "Members view their trip groups" on public.trip_groups;

create policy "Admins manage trip groups"
  on public.trip_groups for all
  using (public.is_trip_admin());

create policy "Members view their trip groups"
  on public.trip_groups for select
  using (id in (select public.my_trip_group_ids()));

-- ---- trip_group_members ----
drop policy if exists "Admins manage group membership"  on public.trip_group_members;
drop policy if exists "Members view their memberships"  on public.trip_group_members;
drop policy if exists "Members view fellow travelers"   on public.trip_group_members;

create policy "Admins manage group membership"
  on public.trip_group_members for all
  using (public.is_trip_admin());

-- Members can see all travelers in groups they belong to (for Team view).
-- Uses my_trip_group_ids() (security definer) to avoid self-referencing recursion.
create policy "Members view fellow travelers"
  on public.trip_group_members for select
  using (group_id in (select public.my_trip_group_ids()));

-- ---- trip_group_info ----
drop policy if exists "Admins manage trip info"          on public.trip_group_info;
drop policy if exists "Members view info for their groups" on public.trip_group_info;

create policy "Admins manage trip info"
  on public.trip_group_info for all
  using (public.is_trip_admin());

create policy "Members view info for their groups"
  on public.trip_group_info for select
  using (group_id in (select public.my_trip_group_ids()));

-- ---- trip_group_documents ----
drop policy if exists "Admins view all documents"       on public.trip_group_documents;
drop policy if exists "Members manage their own documents" on public.trip_group_documents;

create policy "Admins view all documents"
  on public.trip_group_documents for select
  using (public.is_trip_admin());

create policy "Members manage their own documents"
  on public.trip_group_documents for all
  using (member_id = auth.uid());

-- ============================================================
-- Storage bucket for trip documents (run once in the dashboard)
-- ============================================================
-- insert into storage.buckets (id, name, public)
-- values ('trip_documents', 'trip_documents', false)
-- on conflict do nothing;
