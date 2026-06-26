-- ============================================================
-- Multi-admin direct messages
-- ------------------------------------------------------------
-- Previously a member's DM thread was implicitly 1:1 with the
-- Maestro (the table only carried `member_id` + `from_maestro`).
-- Members can now pick ANY admin (branch admin or Maestro) as
-- their counterpart, so a thread key is (member_id, admin_id).
--
-- `from_maestro` is repurposed as "message came from the staff
-- side of the conversation" — we keep the name for compatibility
-- with existing rows but it now means "from_admin".
-- ============================================================

-- 1. Add admin_id; backfill existing rows to a Maestro account.
alter table public.direct_messages
  add column if not exists admin_id uuid references public.members(id) on delete cascade;

update public.direct_messages
   set admin_id = (
     select id from public.members
      where role = 'superAdmin'
      order by created_at asc
      limit 1
   )
 where admin_id is null;

alter table public.direct_messages
  alter column admin_id set not null;

create index if not exists direct_messages_admin_idx
  on public.direct_messages(admin_id, created_at desc);
create index if not exists direct_messages_thread_idx
  on public.direct_messages(member_id, admin_id, created_at);

-- 2. Refresh RLS so reads/writes are scoped to either side of the
--    thread, regardless of which admin it's with.
drop policy if exists "read own dm thread" on public.direct_messages;
create policy "read own dm thread" on public.direct_messages
  for select using (
    member_id = auth.uid()
    or admin_id = auth.uid()
  );

drop policy if exists "send dm" on public.direct_messages;
create policy "send dm" on public.direct_messages
  for insert with check (
    -- Member writes into their own thread with any admin.
    (member_id = auth.uid() and from_maestro = false)
    -- Admin (or Maestro) writes into a thread addressed to them.
    or (admin_id = auth.uid()
        and public.my_role() in ('admin','superAdmin')
        and from_maestro = true)
  );
