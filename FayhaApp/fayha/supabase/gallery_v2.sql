-- ============================================================
-- gallery_v2.sql
-- Run in Supabase SQL editor (idempotent — safe to re-run).
--
-- Adds:
--   • gallery_posts.category         — optional label (Concert, Rehearsal …)
--   • gallery_posts.editors_choice   — boolean; public when true
--   • members.can_upload_gallery     — flag editors/superAdmins can toggle
-- ============================================================

-- ===== 1. New columns =====

ALTER TABLE public.gallery_posts
  ADD COLUMN IF NOT EXISTS category        text,
  ADD COLUMN IF NOT EXISTS editors_choice  boolean NOT NULL DEFAULT false;

ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS can_upload_gallery boolean NOT NULL DEFAULT false;

-- ===== 2. Public read for editors_choice posts (audience home gallery) =====

DROP POLICY IF EXISTS "gallery editors_choice public read" ON public.gallery_posts;
CREATE POLICY "gallery editors_choice public read" ON public.gallery_posts
  FOR SELECT
  USING (editors_choice = true);

-- ===== 3. Allow members with can_upload_gallery to insert =====

DROP POLICY IF EXISTS "gallery permitted member upload" ON public.gallery_posts;
CREATE POLICY "gallery permitted member upload" ON public.gallery_posts
  FOR INSERT TO authenticated
  WITH CHECK (
    public.my_status() = 'active'
    AND (
      public.my_role() IN ('editor', 'superAdmin')
      OR (
        SELECT can_upload_gallery
        FROM public.members
        WHERE id = auth.uid()
      ) = true
    )
  );

-- ===== 4. Allow editors + superAdmins to toggle editors_choice =====

DROP POLICY IF EXISTS "gallery editors_choice update" ON public.gallery_posts;
CREATE POLICY "gallery editors_choice update" ON public.gallery_posts
  FOR UPDATE TO authenticated
  USING  (public.my_role() IN ('editor', 'superAdmin'))
  WITH CHECK (public.my_role() IN ('editor', 'superAdmin'));

-- ===== 5. Allow editors + superAdmins to update can_upload_gallery =====
-- The existing superAdmin member-update policy covers superAdmin.
-- Add a targeted editor policy for this single column.

DROP POLICY IF EXISTS "editors update gallery upload permission" ON public.members;
CREATE POLICY "editors update gallery upload permission" ON public.members
  FOR UPDATE TO authenticated
  USING  (public.my_role() IN ('editor', 'superAdmin'))
  WITH CHECK (public.my_role() IN ('editor', 'superAdmin'));

-- ===== 6. Gallery storage bucket — allow permitted members to upload =====

DROP POLICY IF EXISTS "gallery upload permitted member" ON storage.objects;
CREATE POLICY "gallery upload permitted member" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'gallery_photos'
    AND public.my_status() = 'active'
    AND (
      public.my_role() IN ('editor', 'superAdmin')
      OR (
        SELECT can_upload_gallery
        FROM public.members
        WHERE id = auth.uid()
      ) = true
    )
  );
