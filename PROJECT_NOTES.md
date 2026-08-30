# ACCEAA, GSTU — Alumni Association Website

## What this is
Official website for the Applied Chemistry and Chemical Engineering Alumni
Association, GSTU (ACCEAA, GSTU) — a newly founded (2024) university
department alumni association, based on their adopted Constitution.

## Who's building this
One person (non-technical, no coding background) is doing the full setup
themselves, step by step, with AI guidance. Budget is $0 — everything must
run on free tiers indefinitely. Ongoing site management (adding members,
events, notices, etc.) must happen entirely through an in-app admin panel,
never by editing code or touching a database directly.

## Current state
`index.html` is a **fully designed, fully interactive front-end mockup** —
single HTML file, vanilla JS, no build step, no dependencies except two CDN
scripts (SheetJS for Excel export, jsPDF for PDF export/generation).
All data currently lives in in-memory JS arrays (`alumni`, `execCommittee`,
`events`, `achievementsFull`, `notices`, `partners`, `staffAccounts`, `pending`)
— nothing persists across a page reload yet. This is by design so far: the
mockup was for confirming design/UX before wiring a real backend.

## Design system
- Palette: navy ink (`--ink:#14213D`), brass gold accent (`--brass:#C9A227`),
  cream paper background (`--paper:#F3F2ED`)
- Fonts: Fraunces (serif, headings), Inter (sans, body), IBM Plex Mono (labels/data)
- Fully responsive (desktop/tablet/mobile), hamburger nav below 960px

## Pages / sections (all in one SPA via `switchTab()`)
Home, About Us, Executive Committee, Members (incl. fee tiers, Notices,
searchable Alumni Directory), Events/News (incl. Achievements history),
Submit/Update Info (public, no-login, multi-section form), Contact Us,
and a hidden Admin page (reached via a small "Staff Login" link in the
footer — not in the main nav).

## Admin panel (already built, needs real backend wiring)
- Login: username + password (mock accounts currently hardcoded in
  `staffAccounts` — needs to move to Supabase Auth)
- 2 role tiers: **Admin** (full access, incl. Executive Committee and
  Account Settings) and **Moderator** (Events/News, Members & Directory,
  Achievements, Partners — no Committee/Account access)
- Tabs: Events & News, Members & Directory (incl. full member table with
  double-click-to-edit/delete, PDF/Excel export of all members), Achievements,
  Executive Committee, Membership Form (PDF upload), Notices (PDF upload +
  title/description, CRUD), Partners (add/remove), Account Settings
  (change username/password per staff account)

## Decided real-world architecture (not yet implemented)
- **Hosting:** GitHub Pages, repo name `acceaa-gstu.github.io` (must match
  the GitHub username exactly for the clean root URL). Site will be live at
  `https://acceaa-gstu.github.io/`.
- **Backend:** Supabase free tier — Postgres database, built-in Auth (for
  the 5 staff logins with real hashed passwords instead of the current
  hardcoded array), and Storage (for member photos, committee photos,
  event/notice PDFs).
- Reasoning: zero cost at this scale (~500 members, light file usage),
  no coding needed for day-to-day use once built, data isn't locked in
  (standard Postgres, exportable any time).

## Supabase backend (step 1 — done, see SUPABASE_SETUP.md)
Full schema, RLS policies, storage buckets, and setup walkthrough are
written and ready to run: [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md),
[`supabase/schema.sql`](supabase/schema.sql),
[`supabase/seed_sample_data.sql`](supabase/seed_sample_data.sql),
[`supabase/functions/reset-staff-password/index.ts`](supabase/functions/reset-staff-password/index.ts).
Key decisions made along the way (deviating slightly from a literal 1:1
mapping of the mockup's JS arrays):
- **Sensitive form fields split out of the public directory.** The
  Submit/Update form collects NID, DOB, religion, parents' names,
  addresses, phone numbers — none of which the mockup ever displays
  publicly. These live in a staff-only `member_private_details` table;
  the public `members` table only has what's actually shown today (name,
  batch, programme, org, designation, location, email, photo).
- **Public submissions land in `pending_submissions`**, not directly in
  `members` — matches item 4 below, done up front since it shapes the RLS
  design. An `approve_pending_submission()` DB function does the
  approve → real member conversion in one step for the admin panel to call.
- **Committee is grouped into `committee_terms`** so "Archive current term
  & start new" (already in the mockup UI) has somewhere to point — old
  members stay attached to their archived term for the "Previous
  committees" list.
- **Admin-resets-another-staff-member's-password** (mockup's Account
  Settings) needs a secret key that can't live in front-end code on a
  static GitHub Pages site, so it's a small Supabase Edge Function
  (`reset-staff-password`) instead of a direct client-side call. Staff
  logins use real email addresses (for password-reset emails) rather than
  the mockup's plain usernames.

The user still needs to actually create the Supabase project and run
through `SUPABASE_SETUP.md` themselves (project creation, running the SQL,
creating the 5 logins, deploying the Edge Function) — this wasn't done
automatically since it requires their own Supabase account/login.

## Next steps (the actual remaining work)
1. ~~Set up a Supabase project; design tables matching the current JS arrays~~
   — done, see above. User still needs to execute SUPABASE_SETUP.md.
2. Replace the in-memory arrays and their render functions with real
   Supabase queries (`supabase-js` client, loaded via CDN — no build step
   needed, keeps this deployable as a single static file or a small set
   of files on GitHub Pages).
3. Replace the mock `attemptLogin()` with real Supabase Auth sign-in, and
   gate admin actions server-side via Supabase Row Level Security (RLS)
   policies (critical — right now "admin vs moderator" is purely a
   front-end UI toggle with no real enforcement).
4. Wire the public "Submit/Update Info" form to insert into a
   `pending_submissions` table instead of just showing a success message.
5. Wire file uploads (member photos, committee photos, notice PDFs,
   membership form PDF) to Supabase Storage buckets instead of
   `URL.createObjectURL()` (which only works for the current browser tab).
6. Keep the existing PDF/Excel export features (jsPDF, SheetJS) — those
   work client-side regardless of backend and don't need changes.

## Constraints to respect
- No build tools/frameworks unless there's a strong reason — the person
  maintaining this long-term is non-technical, so keep it as close to
  "plain files you can edit and upload" as reasonably possible.
- All ongoing content changes must go through the admin UI. Never a
  workflow that requires editing this code again for routine updates.
