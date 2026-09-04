-- ============================================================================
-- 1) Persistent visitor identity (U0001, U0002, ...) - one row per
--    returning device/browser (localStorage-based id, persists across
--    visits until the visitor clears site data), not per visit.
-- 2) Member contact-link click tracking - which member's LinkedIn/
--    Facebook/WhatsApp/Email a visitor clicked, from the directory card.
--
-- Run this once in the SQL Editor.
-- ============================================================================

create table public.site_visitors (
  id bigserial primary key,
  device_id text unique not null,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

alter table public.site_visitors enable row level security;
create policy "staff can view visitors" on public.site_visitors
  for select using (public.is_staff());

create or replace function public.get_or_create_visitor(p_device_id text)
returns bigint
language plpgsql security definer
set search_path = public
as $$
declare
  v_id bigint;
begin
  update public.site_visitors set last_seen_at = now() where device_id = p_device_id returning id into v_id;
  if v_id is null then
    insert into public.site_visitors (device_id) values (p_device_id) returning id into v_id;
  end if;
  return v_id;
end;
$$;

grant execute on function public.get_or_create_visitor(text) to anon, authenticated;

alter table public.site_visits add column if not exists visitor_id bigint references public.site_visitors(id);

create table public.member_link_clicks (
  id uuid primary key default gen_random_uuid(),
  clicked_at timestamptz not null default now(),
  member_id uuid references public.members(id) on delete set null,
  member_name text,
  link_type text not null check (link_type in ('linkedin','facebook','whatsapp','email')),
  visitor_id bigint references public.site_visitors(id)
);

create index member_link_clicks_clicked_at_idx on public.member_link_clicks (clicked_at desc);

alter table public.member_link_clicks enable row level security;

create policy "anyone can log a link click" on public.member_link_clicks
  for insert with check (true);
create policy "staff can view link clicks" on public.member_link_clicks
  for select using (public.is_staff());
create policy "admin can clear link clicks" on public.member_link_clicks
  for delete using (public.is_admin());
