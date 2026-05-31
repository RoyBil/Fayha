-- ============================================================
-- Fayha — Attendance
-- Admins take attendance for their own branch; the super admin
-- (Maestro) for any branch. Run after members.sql + messages.sql.
-- ============================================================

create table if not exists public.rehearsals (
  id uuid primary key default gen_random_uuid(),
  branch text not null,
  session_date date not null,
  status text not null default 'held',   -- held | cancelled
  recorded_by uuid references public.members(id) on delete set null,
  recorded_by_name text,
  recorded_at timestamptz default now(),
  created_at timestamptz default now(),
  unique (branch, session_date)
);

-- For tables that already exist:
alter table public.rehearsals
  add column if not exists recorded_at timestamptz default now();

alter table public.rehearsals enable row level security;

drop policy if exists "members read rehearsals" on public.rehearsals;
create policy "members read rehearsals" on public.rehearsals
  for select using (auth.uid() is not null);

drop policy if exists "admins write rehearsals" on public.rehearsals;
create policy "admins write rehearsals" on public.rehearsals
  for all
  using (public.my_role() = 'superAdmin'
         or (public.my_role() = 'admin' and branch = public.my_branch()))
  with check (public.my_role() = 'superAdmin'
         or (public.my_role() = 'admin' and branch = public.my_branch()));

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  rehearsal_id uuid not null references public.rehearsals(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  present boolean not null default false,
  unique (rehearsal_id, member_id)
);

alter table public.attendance enable row level security;

drop policy if exists "members read attendance" on public.attendance;
create policy "members read attendance" on public.attendance
  for select using (auth.uid() is not null);

drop policy if exists "admins write attendance" on public.attendance;
create policy "admins write attendance" on public.attendance
  for all
  using (exists (select 1 from public.rehearsals r
                 where r.id = rehearsal_id
                   and (public.my_role() = 'superAdmin'
                        or (public.my_role() = 'admin'
                            and r.branch = public.my_branch()))))
  with check (exists (select 1 from public.rehearsals r
                 where r.id = rehearsal_id
                   and (public.my_role() = 'superAdmin'
                        or (public.my_role() = 'admin'
                            and r.branch = public.my_branch()))));
