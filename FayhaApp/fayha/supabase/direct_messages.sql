-- ============================================================
-- Fayha — Direct messages (member ↔ Maestro) +
--         remove audience targeting from admin announcements
-- Run once in the Supabase SQL Editor.
-- ============================================================

-- ---- 1:1 chat threads with the Maestro ----
create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  body text not null,
  from_maestro boolean not null default false,
  created_at timestamptz default now()
);

alter table public.direct_messages enable row level security;

-- A member sees only their own thread; the Maestro sees every thread.
drop policy if exists "read own dm thread" on public.direct_messages;
create policy "read own dm thread" on public.direct_messages
  for select using (
    member_id = auth.uid() or public.my_role() = 'superAdmin'
  );

-- A member writes into their own thread; the Maestro writes into any.
drop policy if exists "send dm" on public.direct_messages;
create policy "send dm" on public.direct_messages
  for insert with check (
    (member_id = auth.uid() and from_maestro = false)
    or (public.my_role() = 'superAdmin' and from_maestro = true)
  );

-- ---- Admin announcements no longer reach the audience ----
drop policy if exists "read messages by audience" on public.messages;
create policy "read messages by audience" on public.messages
  for select using (
    (audience = 'members'     and auth.uid() is not null)
    or (audience = 'admins'      and public.my_role() in ('admin', 'superAdmin'))
    or (audience = 'superAdmins' and public.my_role() = 'superAdmin')
    or (audience = 'branch'      and (branch = public.my_branch()
                                      or public.my_role() in ('admin', 'superAdmin')))
  );
