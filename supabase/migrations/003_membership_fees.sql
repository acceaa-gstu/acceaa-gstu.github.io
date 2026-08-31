-- ============================================================================
-- Lets staff edit the membership fee amounts shown on the site (Home page
-- and the Membership page) from the admin panel, instead of them being
-- hardcoded in the site's code.
--
-- Run this once in the SQL Editor.
-- ============================================================================

create table if not exists public.membership_fees (
  tier text primary key check (tier in ('General','Life','Honorary')),
  price text not null,
  note text,
  updated_at timestamptz not null default now()
);

insert into public.membership_fees (tier, price, note) values
  ('General', '৳250', 'one-time'),
  ('Life', '৳2,500', 'renews every 5 yrs'),
  ('Honorary', '—', 'by invitation')
on conflict (tier) do nothing;

alter table public.membership_fees enable row level security;

create policy "public can view membership fees" on public.membership_fees
  for select using (true);
create policy "staff can update membership fees" on public.membership_fees
  for update using (public.is_staff());
