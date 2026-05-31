-- Polls: admin/Maestro create, every active member votes.
-- Three tables: polls, poll_options, poll_votes.

create table if not exists public.polls (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  description text,
  multi_choice boolean not null default false,
  audience text not null default 'members',   -- members | branch | admins | superAdmins
  branch text,                                 -- when audience='branch'
  created_by uuid references public.members(id) on delete set null,
  created_by_name text,
  closes_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.polls(id) on delete cascade,
  text text not null,
  sort_order int not null default 0
);

create table if not exists public.poll_votes (
  poll_id uuid not null references public.polls(id) on delete cascade,
  option_id uuid not null references public.poll_options(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  voted_at timestamptz not null default now(),
  primary key (poll_id, option_id, member_id)
);

create index if not exists poll_options_poll_idx on public.poll_options(poll_id, sort_order);
create index if not exists poll_votes_poll_idx on public.poll_votes(poll_id);
create index if not exists poll_votes_member_idx on public.poll_votes(member_id);

alter table public.polls       enable row level security;
alter table public.poll_options enable row level security;
alter table public.poll_votes  enable row level security;

-- =====  Polls  =====
-- Read: any active member can see polls targeted at them.
drop policy if exists "polls_read" on public.polls;
create policy "polls_read" on public.polls
  for select using (
    public.my_status() = 'active' and (
      audience = 'members'
      or (audience = 'branch' and branch = public.my_branch())
      or (audience = 'admins' and public.my_role() in ('admin','superAdmin'))
      or (audience = 'superAdmins' and public.my_role() = 'superAdmin')
    )
  );

-- Write: admins + superAdmin.
drop policy if exists "polls_insert" on public.polls;
create policy "polls_insert" on public.polls
  for insert with check (
    public.my_role() in ('admin','superAdmin')
  );

drop policy if exists "polls_update" on public.polls;
create policy "polls_update" on public.polls
  for update using (
    public.my_role() = 'superAdmin' or created_by = auth.uid()
  );

drop policy if exists "polls_delete" on public.polls;
create policy "polls_delete" on public.polls
  for delete using (
    public.my_role() = 'superAdmin' or created_by = auth.uid()
  );

-- =====  Poll options  =====
-- Read: anyone who can read the parent poll.
drop policy if exists "poll_options_read" on public.poll_options;
create policy "poll_options_read" on public.poll_options
  for select using (
    exists (select 1 from public.polls p where p.id = poll_id)
  );

-- Write: admin/superAdmin (matches polls insert).
drop policy if exists "poll_options_write" on public.poll_options;
create policy "poll_options_write" on public.poll_options
  for all using (public.my_role() in ('admin','superAdmin'))
  with check (public.my_role() in ('admin','superAdmin'));

-- =====  Poll votes  =====
-- Read: each member sees their own votes + aggregated counts via view below.
drop policy if exists "poll_votes_read_own" on public.poll_votes;
create policy "poll_votes_read_own" on public.poll_votes
  for select using (member_id = auth.uid() or public.my_role() in ('admin','superAdmin'));

-- Cast a vote: only as yourself, and only if you can see the parent poll.
drop policy if exists "poll_votes_insert" on public.poll_votes;
create policy "poll_votes_insert" on public.poll_votes
  for insert with check (
    member_id = auth.uid()
    and exists (select 1 from public.polls p where p.id = poll_id)
  );

drop policy if exists "poll_votes_delete" on public.poll_votes;
create policy "poll_votes_delete" on public.poll_votes
  for delete using (member_id = auth.uid());

-- Public view of vote tallies. Anyone with read access to a poll can read tallies.
create or replace view public.poll_tallies as
  select
    o.poll_id,
    o.id        as option_id,
    o.text      as option_text,
    o.sort_order,
    count(v.member_id) as vote_count
  from public.poll_options o
  left join public.poll_votes v on v.option_id = o.id
  group by o.poll_id, o.id, o.text, o.sort_order;

grant select on public.poll_tallies to authenticated;
