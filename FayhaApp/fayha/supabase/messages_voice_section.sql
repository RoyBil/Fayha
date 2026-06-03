-- Adds a 'voice' audience option to messages so admins can target
-- one voice section (e.g. only Tenor I, only Bass, only Solo) — or
-- a whole group (All Tenors, All Sopranos, All Altos, All Basses,
-- Whole choir). The picked target is stored in `voice_section`.

alter table public.messages
  add column if not exists voice_section text;

-- Member sees a voice-targeted message when:
--   • their section is the exact target, OR
--   • the target is "All Sopranos" and they're a Soprano / Mezzo Soprano, etc.
-- Admins and super admins always see all voice-targeted messages.
drop policy if exists "messages_voice_section_read" on public.messages;
create policy "messages_voice_section_read" on public.messages
  for select using (
    audience != 'voice'
    or voice_section is null
    or public.my_role() in ('admin', 'superAdmin')
    or voice_section = (
      select voice_section from public.members where id = auth.uid()
    )
    or (
      voice_section = 'All Sopranos'
      and (select voice_section from public.members where id = auth.uid())
          in ('Soprano', 'Mezzo Soprano')
    )
    or (
      voice_section = 'All Altos'
      and (select voice_section from public.members where id = auth.uid())
          in ('Alto', 'Contrary Alto')
    )
    or (
      voice_section = 'All Tenors'
      and (select voice_section from public.members where id = auth.uid())
          in ('Tenor I', 'Tenor II')
    )
    or (
      voice_section = 'All Basses'
      and (select voice_section from public.members where id = auth.uid())
          in ('Baritone', 'Bass')
    )
    or voice_section = 'Whole choir'
  );
