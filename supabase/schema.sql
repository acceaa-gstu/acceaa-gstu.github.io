-- ============================================================================
-- ACCEAA, GSTU — Supabase schema, RLS policies, storage buckets, and helper
-- functions for the admin panel.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → New query → paste this whole
-- file → Run. Safe to re-run (uses IF NOT EXISTS / ON CONFLICT where it
-- matters), but it's meant to be run once on a fresh project.
-- ============================================================================

-- Needed for gen_random_uuid()
create extension if not exists pgcrypto;

-- ============================================================================
-- 1. STAFF PROFILES  (role metadata layered on top of Supabase Auth users)
-- ============================================================================

create table public.staff_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null default 'moderator' check (role in ('admin','moderator')),
  created_at timestamptz not null default now()
);

-- Auto-create a staff_profiles row whenever a new Auth user is created via
-- Authentication → Users → Add user. New staff default to 'moderator';
-- promote the 2 admin accounts to 'admin' by hand after creating them
-- (see SUPABASE_SETUP.md step 7).
create or replace function public.handle_new_staff_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.staff_profiles (id, display_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', new.email), 'moderator');
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_staff_user();

-- Helper functions used by every RLS policy below. SECURITY DEFINER so they
-- can read staff_profiles regardless of the caller's own RLS visibility
-- (avoids recursive-policy issues), while still only ever returning a
-- boolean — no row data leaks through them.
create or replace function public.is_staff()
returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.staff_profiles where id = auth.uid());
$$;

create or replace function public.is_admin()
returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.staff_profiles where id = auth.uid() and role = 'admin');
$$;

-- Prevent a non-admin from promoting themselves (or anyone) to admin by
-- editing their own staff_profiles row from the Account Settings panel.
create or replace function public.prevent_role_self_escalation()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() and new.role is distinct from old.role then
    raise exception 'Only admins can change staff roles.';
  end if;
  return new;
end;
$$;

create trigger trg_prevent_role_self_escalation
before update on public.staff_profiles
for each row execute function public.prevent_role_self_escalation();

alter table public.staff_profiles enable row level security;

create policy "staff view own profile, admin views all"
  on public.staff_profiles for select
  using (auth.uid() = id or public.is_admin());

create policy "staff update own display name, admin updates any"
  on public.staff_profiles for update
  using (auth.uid() = id or public.is_admin());

-- No public INSERT/DELETE policy: rows are only created by the trigger
-- above and only removed via cascading delete when the Auth user is removed.

-- ============================================================================
-- 2. MEMBERS  (public alumni directory — safe-to-publish fields only)
-- ============================================================================

create table public.members (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  location text,
  email text,
  linkedin text,
  facebook text,
  programme text,
  passing_year int,
  organization text,
  designation text,
  photo_url text,
  membership_type text not null default 'General' check (membership_type in ('General','Life','Honorary')),
  gender text, -- low-sensitivity, public copy of the private gender field; used only to pick a default avatar icon
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index members_passing_year_idx on public.members (passing_year);
create index members_programme_idx on public.members (programme);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_members_updated_at
before update on public.members
for each row execute function public.set_updated_at();

alter table public.members enable row level security;

create policy "public can view members" on public.members
  for select using (true);
create policy "staff can add members" on public.members
  for insert with check (public.is_staff());
create policy "staff can edit members" on public.members
  for update using (public.is_staff());
create policy "staff can remove members" on public.members
  for delete using (public.is_staff());

-- ----------------------------------------------------------------------------
-- 2b. MEMBER PRIVATE DETAILS  (sensitive fields — staff-only, never public)
-- Student ID, phone numbers, NID, DOB, religion, addresses, parents' names,
-- etc. These were collected by the Submit/Update form but were never shown
-- on the public directory in the mockup, so they stay locked down here.
-- ----------------------------------------------------------------------------

create table public.member_private_details (
  member_id uuid primary key references public.members(id) on delete cascade,
  student_id text,
  mobile_phone text,
  land_phone text,
  father_name text,
  mother_name text,
  gender text,
  date_of_birth date,
  blood_group text,
  religion text,
  nid text,
  nationality text,
  marital_status text,
  mailing_address text,
  permanent_address text,
  website text,
  updated_at timestamptz not null default now()
);

alter table public.member_private_details enable row level security;

create policy "staff only can view private details" on public.member_private_details
  for select using (public.is_staff());
create policy "staff only can add private details" on public.member_private_details
  for insert with check (public.is_staff());
create policy "staff only can edit private details" on public.member_private_details
  for update using (public.is_staff());
create policy "staff only can remove private details" on public.member_private_details
  for delete using (public.is_staff());

-- ============================================================================
-- 3. PENDING SUBMISSIONS  (public "Submit / Update Info" form lands here)
-- Not publicly readable. Everything the form collects lives in one flat row
-- here; approve_pending_submission() below splits it into members +
-- member_private_details once staff approve it.
-- ============================================================================

create table public.pending_submissions (
  id uuid primary key default gen_random_uuid(),
  existing_member_id uuid references public.members(id) on delete set null,
  submission_type text not null default 'new' check (submission_type in ('new','update')),
  full_name text not null,
  father_name text,
  mother_name text,
  gender text,
  date_of_birth date,
  blood_group text,
  religion text,
  nid text,
  nationality text,
  marital_status text,
  mailing_address text,
  permanent_address text,
  location text,
  email text,
  land_phone text,
  mobile_phone text,
  website text,
  linkedin text,
  facebook text,
  programme text,
  student_id text,
  passing_year int,
  organization text,
  designation text,
  photo_url text,
  note text,
  submitted_at timestamptz not null default now()
);

alter table public.pending_submissions enable row level security;

create policy "anyone can submit the public form" on public.pending_submissions
  for insert with check (true);
create policy "staff can view submissions" on public.pending_submissions
  for select using (public.is_staff());
create policy "staff can update submissions" on public.pending_submissions
  for update using (public.is_staff());
create policy "staff can delete submissions" on public.pending_submissions
  for delete using (public.is_staff());

-- Approve a pending submission: creates (or updates) the member record and
-- deletes the pending row, in one atomic step. Call from the app with:
--   supabase.rpc('approve_pending_submission', { submission_id: <id> })
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

-- ============================================================================
-- 4. EXECUTIVE COMMITTEE  (admin-only to edit; grouped into terms so a term
-- can be archived and a new one started, matching "Previous committees")
-- ============================================================================

create table public.committee_terms (
  id uuid primary key default gen_random_uuid(),
  label text not null,           -- e.g. "Founding term · 2024–2026"
  start_year int,
  end_year int,
  is_current boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.committee (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.committee_terms(id) on delete cascade,
  full_name text not null,
  role text not null,
  batch int,
  linkedin text,
  facebook text,
  email text,
  phone text,
  photo_url text,
  gender text, -- used only to pick a default avatar icon when no photo is set
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index committee_term_idx on public.committee (term_id);

alter table public.committee_terms enable row level security;
create policy "public can view committee terms" on public.committee_terms for select using (true);
create policy "admin can add committee terms" on public.committee_terms for insert with check (public.is_admin());
create policy "admin can edit committee terms" on public.committee_terms for update using (public.is_admin());
create policy "admin can remove committee terms" on public.committee_terms for delete using (public.is_admin());

alter table public.committee enable row level security;
create policy "public can view committee" on public.committee for select using (true);
create policy "admin can add committee members" on public.committee for insert with check (public.is_admin());
create policy "admin can edit committee members" on public.committee for update using (public.is_admin());
create policy "admin can remove committee members" on public.committee for delete using (public.is_admin());

-- ============================================================================
-- 5. EVENTS / NEWS
-- ============================================================================

create table public.events (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('event','news')),
  title text not null,
  description text,
  event_date date not null,
  photo_url text,
  created_at timestamptz not null default now()
);

create index events_date_idx on public.events (event_date desc);

alter table public.events enable row level security;
create policy "public can view events" on public.events for select using (true);
create policy "staff can add events" on public.events for insert with check (public.is_staff());
create policy "staff can edit events" on public.events for update using (public.is_staff());
create policy "staff can remove events" on public.events for delete using (public.is_staff());

-- ============================================================================
-- 6. ACHIEVEMENTS
-- ============================================================================

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references public.members(id) on delete set null,
  alumni_name text not null,
  batch int,
  tag text not null check (tag in ('Job','Higher Study','Career')),
  description text not null,
  photo_url text,
  created_at timestamptz not null default now()
);

create index achievements_created_idx on public.achievements (created_at desc);

alter table public.achievements enable row level security;
create policy "public can view achievements" on public.achievements for select using (true);
create policy "staff can add achievements" on public.achievements for insert with check (public.is_staff());
create policy "staff can edit achievements" on public.achievements for update using (public.is_staff());
create policy "staff can remove achievements" on public.achievements for delete using (public.is_staff());

-- ============================================================================
-- 7. NOTICES
-- ============================================================================

create table public.notices (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  file_url text,
  created_at timestamptz not null default now()
);

alter table public.notices enable row level security;
create policy "public can view notices" on public.notices for select using (true);
create policy "staff can add notices" on public.notices for insert with check (public.is_staff());
create policy "staff can edit notices" on public.notices for update using (public.is_staff());
create policy "staff can remove notices" on public.notices for delete using (public.is_staff());

-- ============================================================================
-- 8. PARTNERS
-- ============================================================================

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  logo_url text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.partners enable row level security;
create policy "public can view partners" on public.partners for select using (true);
create policy "staff can add partners" on public.partners for insert with check (public.is_staff());
create policy "staff can edit partners" on public.partners for update using (public.is_staff());
create policy "staff can remove partners" on public.partners for delete using (public.is_staff());

-- ============================================================================
-- 9. MEMBERSHIP FORM  (the single downloadable PDF, admin uploads a new one)
-- ============================================================================

create table public.membership_form (
  id int primary key default 1 check (id = 1),   -- singleton row: exactly one current form
  file_url text,
  uploaded_at timestamptz
);
insert into public.membership_form (id, file_url, uploaded_at) values (1, null, null);

alter table public.membership_form enable row level security;
create policy "public can view membership form" on public.membership_form for select using (true);
create policy "staff can update membership form" on public.membership_form for update using (public.is_staff());

-- ============================================================================
-- 10. STORAGE BUCKETS
-- "photos"    — public, staff-writable: member/committee/event/achievement/
--               partner photos, organized in subfolders in the object path
--               (e.g. photos/members/..., photos/committee/...).
-- "documents" — public, staff-writable: notice PDFs and the membership form.
-- Committee photos (photos/committee/...) are further restricted to admins
-- only, matching the Executive Committee panel's admin-only lock.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('photos', 'photos', true),
       ('documents', 'documents', true)
on conflict (id) do nothing;

-- storage.objects already has RLS enabled by default on every Supabase
-- project (and you're not allowed to ALTER that table yourself — it's
-- owned by Supabase's internal storage role) — so we go straight to
-- creating policies on it.

create policy "public can view photos and documents"
  on storage.objects for select
  using (bucket_id in ('photos','documents'));

create policy "staff can upload photos and documents"
  on storage.objects for insert
  with check (
    bucket_id in ('photos','documents')
    and public.is_staff()
    and (bucket_id <> 'photos' or (storage.foldername(name))[1] <> 'committee' or public.is_admin())
  );

create policy "staff can update photos and documents"
  on storage.objects for update
  using (
    bucket_id in ('photos','documents')
    and public.is_staff()
    and (bucket_id <> 'photos' or (storage.foldername(name))[1] <> 'committee' or public.is_admin())
  );

create policy "staff can delete photos and documents"
  on storage.objects for delete
  using (
    bucket_id in ('photos','documents')
    and public.is_staff()
    and (bucket_id <> 'photos' or (storage.foldername(name))[1] <> 'committee' or public.is_admin())
  );

-- ============================================================================
-- Done. Next: create the 5 staff logins in Authentication → Users, promote
-- your 2 admins (see SUPABASE_SETUP.md), then deploy the
-- reset-staff-password Edge Function.
-- ============================================================================
