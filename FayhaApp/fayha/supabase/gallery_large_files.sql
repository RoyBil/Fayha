-- Raises the per-file size limit on the gallery bucket so editors can
-- post longer videos. Default Supabase storage cap is 50 MB; this
-- bumps gallery_photos to 500 MB. Adjust as your plan allows.
--
-- (You can also change this in the dashboard:
--  Storage → gallery_photos → Configuration → File size limit)

update storage.buckets
   set file_size_limit = 5368709120  -- 5 GB
 where id = 'gallery_photos';

-- Verify the new value (run this and check it returns 5368709120):
-- select id, file_size_limit from storage.buckets where id = 'gallery_photos';

-- Allow the bucket to accept any image or video MIME type.
update storage.buckets
   set allowed_mime_types = null
 where id = 'gallery_photos';
