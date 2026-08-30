# Supabase backend setup — step by step

Follow these in order. Nothing here touches `index.html` yet — that's the
next phase, once this backend exists. This just builds the database, the 5
staff logins, file storage, and the one small server-side function the
admin panel needs.

You'll need about 20–30 minutes, and no credit card (Supabase's free tier
covers this project comfortably).

---

## 1. Create your Supabase account

1. Go to **https://supabase.com** and click **Start your project**.
2. Sign up (GitHub sign-in is fastest, or use email).
3. You'll land on the Supabase dashboard.

## 2. Create the project

1. Click **New project**.
2. **Name:** `acceaa-gstu` (or anything you'll recognize).
3. **Database password:** generate/enter a strong one and **save it
   somewhere safe** (a password manager). This is *not* one of the 5 staff
   logins — it's the master Postgres password, only needed for advanced
   direct-database access, which you likely won't use again.
4. **Region:** pick the one closest to Bangladesh — usually
   `ap-southeast-1 (Singapore)`.
5. Click **Create new project** and wait ~2 minutes while it provisions.

## 3. Run the schema

1. In the left sidebar, open **SQL Editor**.
2. Click **New query**.
3. Open [`supabase/schema.sql`](supabase/schema.sql) from this repo, copy
   the whole file, paste it into the query editor.
4. Click **Run**. You should see "Success. No rows returned."

This creates every table (members, committee, events, achievements,
notices, partners, staff profiles, pending submissions), turns on Row Level
Security with the correct public/staff/admin rules on all of them, and
creates the two Storage buckets (`photos`, `documents`).

**Privacy note:** the form on Submit/Update Info collects sensitive fields
(NID, date of birth, religion, parents' names, addresses, phone numbers).
Those are *not* part of the public directory in the mockup, so the schema
keeps them in a separate `member_private_details` table that only staff
logins can ever read — the public `members` table only holds what the
mockup already shows publicly (name, batch, programme, organization,
designation, location, email, photo).

## 4. (Optional) Load sample data to test with

If you want to see the site working with realistic data before entering
real alumni:

1. New query in the SQL Editor.
2. Paste in [`supabase/seed_sample_data.sql`](supabase/seed_sample_data.sql)
   and run it.
3. Before going live for real, come back to this file and run the `DELETE`
   statements at the bottom (currently commented out) to clear the test
   data.

## 5. Confirm the storage buckets

**Storage** in the sidebar → you should see two buckets, both marked
**Public**:
- `photos` — member/committee/event/achievement/partner photos
- `documents` — notice PDFs and the membership form PDF

(These were created automatically by the schema script — this step is just
to confirm they're there.)

## 6. Create the 5 staff logins

1. **Authentication → Users → Add user**.
2. For each of the 5 staff accounts (2 Admins, 3 Moderators):
   - **Email:** a real email address that person can receive mail at
     (needed later for password-reset emails — this replaces the
     mockup's plain "username").
   - **Password:** a temporary one they should change after first login.
   - Check **Auto Confirm User** (skips the email-confirmation step).
   - Click **Create user**.
3. Do this 5 times.

Each new user automatically gets a row in `staff_profiles` with the role
`moderator` — that's step 7.

## 7. Promote your 2 Admins

1. **SQL Editor → New query**, run:
   ```sql
   select id, email from auth.users order by created_at;
   ```
2. Note the `id` (a UUID) next to each of your 5 staff emails.
3. For your **2 Admin** accounts, run (one line per person, with their real
   UUID and a display name). The SQL Editor runs as the database
   superuser, not as a logged-in staff member, so the trigger that stops
   non-admins from self-promoting can't tell you're an admin here — wrap
   the update by switching the trigger off and back on:
   ```sql
   alter table public.staff_profiles disable trigger trg_prevent_role_self_escalation;

   update public.staff_profiles
   set role = 'admin', display_name = 'Full Name Here'
   where id = 'paste-their-uuid-here';

   alter table public.staff_profiles enable trigger trg_prevent_role_self_escalation;
   ```
   (This is only needed here in the SQL Editor. Once the app itself
   promotes/demotes staff through a logged-in admin session, the trigger
   works normally.)
4. For your **3 Moderator** accounts, just fix the display name (role is
   already `moderator` by default):
   ```sql
   update public.staff_profiles
   set display_name = 'Full Name Here'
   where id = 'paste-their-uuid-here';
   ```

## 8. Deploy the password-reset function

The mockup lets an Admin reset any other staff member's password directly.
That specific action needs to run on Supabase's servers (never in the
browser), so it's a small Edge Function:

1. **Edge Functions** in the sidebar → **Create a new function**.
2. Name it exactly `reset-staff-password`.
3. Open [`supabase/functions/reset-staff-password/index.ts`](supabase/functions/reset-staff-password/index.ts),
   copy the whole file, paste it into the function editor.
4. Click **Deploy**.

No secrets to configure — Supabase automatically provides the function
with the project URL, anon key, and service-role key it needs.

Leave **Enforce JWT verification** on its default (enabled) — the function
also does its own check that the caller is a logged-in Admin before it
touches anyone's password.

## 9. Save your project credentials for the next step

**Project Settings → API**, note down:
- **Project URL**
- **`anon` `public` key**

You'll hand these to me when we wire `index.html` up to this backend (the
next phase). They're safe to put in the front-end code — that's what the
`anon` key and Row Level Security are designed for.

⚠️ **Never** put the **`service_role`** key anywhere in `index.html` or any
file that goes into the GitHub Pages repo — it bypasses every security
rule we just set up. It's only ever used automatically, server-side, inside
the Edge Function.

---

## What's built vs. what's next

**Done by this setup:**
- All 7 content tables + private-details table + pending-submissions table
- Row Level Security matching the mockup's Admin vs. Moderator split
  (Executive Committee and staff-role changes are Admin-only; everything
  else is any staff)
- 2 Storage buckets for photos and PDFs, with the same admin-only rule for
  committee photos
- The 5 real staff logins via Supabase Auth
- The one server-side function the panel needs (password resets)
- An `approve_pending_submission()` database function the app can call to
  turn an approved public submission into a real directory entry in one
  step

**Still to do (separate step, not started yet):**
- Replace the in-memory JS arrays in `index.html` with real Supabase
  queries (`supabase-js` via CDN)
- Replace `attemptLogin()` with real Supabase Auth sign-in
- Wire the Submit/Update form to insert into `pending_submissions`
- Wire photo/PDF uploads to the `photos` / `documents` buckets instead of
  `URL.createObjectURL()`

Let me know once you've completed steps 1–9 (or if you get stuck on any of
them), and whether you'd like to move on to wiring `index.html` next.
