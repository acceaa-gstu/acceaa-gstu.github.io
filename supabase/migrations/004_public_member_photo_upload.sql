-- ============================================================================
-- Fixes: the public Submit/Update Info form (no login) couldn't upload a
-- photo - the storage policy only allowed logged-in staff to upload to the
-- "photos" bucket at all, but the public form needs to upload the
-- submitter's own photo into photos/members/ before they're staff-approved.
--
-- Run this once in the SQL Editor.
-- ============================================================================

drop policy if exists "staff can upload photos and documents" on storage.objects;

create policy "staff can upload photos and documents"
  on storage.objects for insert
  with check (
    bucket_id in ('photos','documents')
    and (
      -- anyone (no login) can upload their own photo via the public Submit/Update form
      (bucket_id = 'photos' and (storage.foldername(name))[1] = 'members')
      or (
        public.is_staff()
        and (bucket_id <> 'photos' or (storage.foldername(name))[1] <> 'committee' or public.is_admin())
      )
    )
  );
