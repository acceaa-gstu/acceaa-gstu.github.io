-- ============================================================================
-- Adds "how long did they stay" to visitor tracking. The page reports
-- elapsed time back periodically (and once more when the tab closes) via a
-- narrow RPC that can only ever touch duration_seconds on the one row it
-- just inserted - no general anonymous UPDATE grant on the table.
--
-- Run this once in the SQL Editor.
-- ============================================================================

alter table public.site_visits add column if not exists duration_seconds integer not null default 0;

create or replace function public.update_visit_duration(visit_id uuid, seconds int)
returns void
language sql security definer
set search_path = public
as $$
  update public.site_visits set duration_seconds = greatest(0, seconds) where id = visit_id;
$$;

grant execute on function public.update_visit_duration(uuid, int) to anon, authenticated;
