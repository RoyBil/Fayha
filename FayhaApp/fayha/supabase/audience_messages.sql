-- ============================================================
-- Fayha — Allow admin messages to reach the audience again.
-- Run once in the Supabase SQL Editor.
-- ============================================================

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
