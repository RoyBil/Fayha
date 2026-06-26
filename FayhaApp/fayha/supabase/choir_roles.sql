-- ============================================================
-- Choir roles (replaces the old singer level)
-- ------------------------------------------------------------
-- The `singer_level` column now stores one of:
--   not_on_stage | on_stage | assistant_conductor | friend | null
--
-- Per product decision (June 2026): existing beginner / intermediate /
-- professional values are wiped so admins can re-classify everyone
-- against the new categories.
-- ============================================================

-- 1. Wipe legacy values BEFORE swapping the check constraint, otherwise
--    the new constraint would refuse to attach.
update public.members
   set singer_level = null
 where singer_level in ('beginner', 'intermediate', 'professional');

-- 2. Swap the CHECK constraint to the new allowed set.
alter table public.members
  drop constraint if exists members_singer_level_check;

alter table public.members
  add constraint members_singer_level_check
    check (singer_level is null
        or singer_level in (
             'not_on_stage', 'on_stage',
             'assistant_conductor', 'friend'
           ));
