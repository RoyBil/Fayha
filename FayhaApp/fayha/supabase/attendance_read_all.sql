-- Lets any active member read attendance rows so the member-detail
-- page can show everyone's rehearsal count. We only count rows;
-- nobody can write someone else's attendance (write policies are
-- unchanged — only admins record attendance).

drop policy if exists "attendance read all members" on public.attendance;
create policy "attendance read all members" on public.attendance
  for select using (public.my_status() = 'active');
