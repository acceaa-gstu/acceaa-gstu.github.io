-- ============================================================================
-- Now that anonymous visitors can upload into photos/members/ (see migration
-- 004), lock the bucket down to image files only, with a size cap - so an
-- anonymous upload can't be a huge file, an arbitrary file type, or used to
-- fill up storage quota. Same for "documents" (PDF only), even though that
-- one is staff-only, for consistency.
--
-- Run this once in the SQL Editor.
-- ============================================================================

update storage.buckets
set file_size_limit = 5242880, -- 5 MB
    allowed_mime_types = array['image/jpeg','image/png','image/webp']
where id = 'photos';

update storage.buckets
set file_size_limit = 10485760, -- 10 MB
    allowed_mime_types = array['application/pdf']
where id = 'documents';
