-- ============================================================
-- Fayha — Admin messages / announcements
-- Run once in the Supabase SQL Editor, AFTER members.sql.
-- ============================================================

-- Helper: current user's branch (security definer = no RLS recursion).
create or replace function public.my_branch()
returns text language sql security definer stable
as $$ select branch from public.members where id = auth.uid() $$;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience text not null,   -- everyone | audience | members | admins | superAdmins | branch
  branch text,              -- set only when audience = 'branch'
  sender_id uuid references public.members(id) on delete set null,
  sender_name text,
  created_at timestamptz default now()
);

alter table public.messages enable row level security;

-- Who can READ a message depends on its audience.
drop policy if exists "read messages by audience" on public.messages;
create policy "read messages by audience" on public.messages
  for select using (
    audience in ('everyone', 'audience')
    or (audience = 'members'     and auth.uid() is not null)
    or (audience = 'admins'      and public.my_role() in ('admin', 'superAdmin'))
    or (audience = 'superAdmins' and public.my_role() = 'superAdmin')
    or (audience = 'branch'      and (branch = public.my_branch()
                                      or public.my_role() in ('admin', 'superAdmin')))
  );

-- Only admins / super admins can send or delete messages.
drop policy if exists "admins send messages" on public.messages;
create policy "admins send messages" on public.messages
  for insert with check (public.my_role() in ('admin', 'superAdmin'));

drop policy if exists "admins delete messages" on public.messages;
create policy "admins delete messages" on public.messages
  for delete using (public.my_role() in ('admin', 'superAdmin'));
