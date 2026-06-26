-- Per-member in-app notifications.
-- Used for events like being added to a trip group.
create table if not exists public.member_notifications (
  id         uuid        primary key default gen_random_uuid(),
  member_id  uuid        not null references public.members(id) on delete cascade,
  kind       text        not null,   -- 'trip_added' | ...
  title      text        not null,
  body       text        not null,
  source_id  text,                    -- trip_group id for deep-linking
  created_at timestamptz not null default now()
);

alter table public.member_notifications enable row level security;

drop policy if exists "Members view own notifications" on public.member_notifications;
drop policy if exists "Admins insert notifications"    on public.member_notifications;

-- Members see only their own notifications.
create policy "Members view own notifications"
  on public.member_notifications for select
  using (member_id = auth.uid());

-- Admins (trip admins) can insert notifications for any member.
create policy "Admins insert notifications"
  on public.member_notifications for insert
  with check (public.is_trip_admin());
