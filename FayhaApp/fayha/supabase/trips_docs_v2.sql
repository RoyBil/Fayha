-- ============================================================
-- trips_docs_v2.sql
-- Run in Supabase SQL editor (idempotent — safe to re-run).
--
-- Adds:
--   • 'profile_photo' to trip_group_documents.document_type
--
-- If document_type is a TEXT column with a CHECK constraint,
-- the lines below drop and recreate the constraint to include
-- the new value.  If it is a PostgreSQL ENUM type instead,
-- comment out everything below and run:
--   ALTER TYPE document_type ADD VALUE IF NOT EXISTS 'profile_photo';
-- ============================================================

ALTER TABLE public.trip_group_documents
  DROP CONSTRAINT IF EXISTS trip_group_documents_document_type_check;

ALTER TABLE public.trip_group_documents
  ADD CONSTRAINT trip_group_documents_document_type_check
  CHECK (document_type IN (
    'passport',
    'visa',
    'insurance',
    'profile_photo',
    'other'
  ));
