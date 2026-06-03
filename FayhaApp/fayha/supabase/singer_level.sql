-- A self-declared (or admin-assigned) singer experience level
-- shown as a small badge on the member detail / directory screens.
-- Allowed values: 'beginner' | 'intermediate' | 'professional'.

alter table public.members
  add column if not exists singer_level text
    check (singer_level is null
      or singer_level in ('beginner', 'intermediate', 'professional'));
