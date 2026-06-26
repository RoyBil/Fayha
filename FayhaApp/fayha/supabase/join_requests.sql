-- Public audience members can request to join the choir via the
-- Join screen. The request lands here and shows up in the admin
-- panel under "Join Requests" for the team to follow up on.

create table if not exists public.join_requests (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  email       text not null,
  phone       text not null,
  village     text not null,
  branch      text,                          -- chosen branch (added later)
  notes       text,
  status      text not null default 'new',  -- new | contacted | dismissed
  created_at  timestamptz not null default now(),
  handled_by  uuid references public.members(id) on delete set null,
  handled_at  timestamptz
);

-- Backfill column on already-deployed tables.
alter table public.join_requests
  add column if not exists branch text;

create index if not exists join_requests_status_idx
  on public.join_requests(status, created_at desc);

alter table public.join_requests enable row level security;

-- Anyone — even unauthenticated audience visitors — can submit a request.
drop policy if exists "join_requests_insert_public" on public.join_requests;
create policy "join_requests_insert_public" on public.join_requests
  for insert to public
  with check (true);

-- Only admins / Maestro can read or manage them.
drop policy if exists "join_requests_read_admin" on public.join_requests;
create policy "join_requests_read_admin" on public.join_requests
  for select using (public.my_role() in ('admin','superAdmin'));

drop policy if exists "join_requests_update_admin" on public.join_requests;
create policy "join_requests_update_admin" on public.join_requests
  for update using (public.my_role() in ('admin','superAdmin'));

drop policy if exists "join_requests_delete_admin" on public.join_requests;
create policy "join_requests_delete_admin" on public.join_requests
  for delete using (public.my_role() in ('admin','superAdmin'));
