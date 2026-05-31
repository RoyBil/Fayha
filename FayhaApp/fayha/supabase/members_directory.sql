-- Let every active member read every other active/deactivated member.
-- This powers the Members Directory screen so every account (audience
-- excluded — they don't sign in) can see Maestro, Amir, Adam, etc.

drop policy if exists "members read directory" on public.members;

create policy "members read directory" on public.members
  for select using (
    public.my_status() = 'active'
    and status in ('active', 'deactivated')
  );
