-- ============================================================================
-- Adds a public, low-sensitivity "gender" field to `members` and `committee`
-- so the site can pick the right default avatar (male/female icon) when no
-- photo has been uploaded. This does NOT touch the other private fields
-- (DOB, NID, religion, addresses, etc.) — those stay staff-only.
--
-- Run this once in the SQL Editor. Safe to run on a project that already
-- has schema.sql applied.
-- ============================================================================

alter table public.members add column if not exists gender text;
alter table public.committee add column if not exists gender text;

-- Backfill existing members' public gender from their already-collected
-- private record, so current directory entries pick up the right icon too.
update public.members m
set gender = p.gender
from public.member_private_details p
where p.member_id = m.id and m.gender is null and p.gender is not null;

-- Update approve_pending_submission() so newly approved members also get
-- their public gender set (it already copies everything else).
create or replace function public.approve_pending_submission(submission_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.pending_submissions%rowtype;
  target_id uuid;
begin
  if not public.is_staff() then
    raise exception 'Only staff can approve submissions';
  end if;

  select * into s from public.pending_submissions where id = submission_id;
  if not found then
    raise exception 'Submission not found';
  end if;

  if s.submission_type = 'update' and s.existing_member_id is not null then
    target_id := s.existing_member_id;
    update public.members set
      full_name = s.full_name, location = s.location, email = s.email,
      linkedin = s.linkedin, facebook = s.facebook, programme = s.programme,
      passing_year = s.passing_year, organization = s.organization,
      designation = s.designation, photo_url = coalesce(s.photo_url, photo_url),
      gender = coalesce(s.gender, gender),
      updated_at = now()
    where id = target_id;
  else
    insert into public.members (full_name, location, email, linkedin, facebook, programme,
      passing_year, organization, designation, photo_url, gender)
    values (s.full_name, s.location, s.email, s.linkedin, s.facebook, s.programme,
      s.passing_year, s.organization, s.designation, s.photo_url, s.gender)
    returning id into target_id;
  end if;

  insert into public.member_private_details (member_id, student_id, mobile_phone, land_phone,
    father_name, mother_name, gender, date_of_birth, blood_group, religion, nid, nationality,
    marital_status, mailing_address, permanent_address, website, updated_at)
  values (target_id, s.student_id, s.mobile_phone, s.land_phone, s.father_name, s.mother_name,
    s.gender, s.date_of_birth, s.blood_group, s.religion, s.nid, s.nationality, s.marital_status,
    s.mailing_address, s.permanent_address, s.website, now())
  on conflict (member_id) do update set
    student_id = excluded.student_id, mobile_phone = excluded.mobile_phone, land_phone = excluded.land_phone,
    father_name = excluded.father_name, mother_name = excluded.mother_name, gender = excluded.gender,
    date_of_birth = excluded.date_of_birth, blood_group = excluded.blood_group, religion = excluded.religion,
    nid = excluded.nid, nationality = excluded.nationality, marital_status = excluded.marital_status,
    mailing_address = excluded.mailing_address, permanent_address = excluded.permanent_address,
    website = excluded.website, updated_at = now();

  delete from public.pending_submissions where id = submission_id;
  return target_id;
end;
$$;
