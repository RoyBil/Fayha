-- Allow members to read all votes for any poll they can see, so the
-- poll_tallies view returns correct counts. Members can already see who
-- voted within their own audience.

drop policy if exists "poll_votes_read_own" on public.poll_votes;

create policy "poll_votes_read" on public.poll_votes
  for select using (
    exists (select 1 from public.polls p where p.id = poll_id)
  );
