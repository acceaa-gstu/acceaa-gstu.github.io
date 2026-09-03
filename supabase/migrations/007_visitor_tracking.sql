-- ============================================================================
-- Visitor tracking. Logs one row per site visit (not per page/section view),
-- capturing only what a browser can report about itself - no IP address and
-- no location, by design (that would need sending the visitor's IP to a
-- third-party lookup service, which we're deliberately not doing).
--
-- Captured per visit: when, which page/deep-link they landed on, where they
-- came from (referrer), and browser/device/OS parsed from the user-agent
-- string. Visible to staff in the admin panel and downloadable as Excel.
--
-- Run this once in the SQL Editor.
-- ============================================================================

create table public.site_visits (
  id uuid primary key default gen_random_uuid(),
  visited_at timestamptz not null default now(),
  page_path text,
  referrer text,
  user_agent text,
  browser text,
  os text,
  device_type text,
  session_id text
);

create index site_visits_visited_at_idx on public.site_visits (visited_at desc);

alter table public.site_visits enable row level security;

create policy "anyone can log a visit" on public.site_visits
  for insert with check (true);
create policy "staff can view visitor logs" on public.site_visits
  for select using (public.is_staff());
create policy "admin can clear visitor logs" on public.site_visits
  for delete using (public.is_admin());
