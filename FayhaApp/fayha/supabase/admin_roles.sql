-- ============================================================
-- Fayha — Role permissions
-- Approving members, pausing/removing accounts, and promoting
-- admins are SUPER-ADMIN ONLY. Admins can do everything else.
-- Run once in the Supabase SQL Editor, AFTER members.sql.
-- ============================================================

-- Replace the old "admins update members" policy: only the super
-- admin (Maestro) may change another member's status or role.
drop policy if exists "admins update members" on public.members;
drop policy if exists "superadmin updates members" on public.members;
create policy "superadmin updates members" on public.members
  for update using (public.my_role() = 'superAdmin');

-- (The "update own member row" policy stays — every member can
--  still edit their own profile. The "admins read all members"
--  policy stays — admins can still view the roster.)
