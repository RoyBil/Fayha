-- ============================================================
-- Fayha — QR-code attendance
-- Admin/maestro opens a session on the day's rehearsal → app
-- generates a token + QR. Members scan it with the app; an RPC
-- writes into the existing `attendance` table (so stats & sheets
-- keep working) and records location + exact time.
-- QR is valid for 3 hours. Late = scan time after `late_after`.
-- ============================================================

-- ===== QR sessions =====
create table if not exists public.qr_sessions (
  id           uuid primary key default gen_random_uuid(),
  rehearsal_id uuid not null references public.rehearsals(id) on delete cascade,
  branch       text not null,
  token        text not null unique,
  started_at   timestamptz not null default now(),
  expires_at   timestamptz not null default (now() + interval '3 hours'),
  late_after   timestamptz,   -- scans after this are flagged as late
  created_by   uuid references public.members(id) on delete set null
);

create index if not exists qr_sessions_rehearsal_idx
  on public.qr_sessions (rehearsal_id);
create index if not exists qr_sessions_active_idx
  on public.qr_sessions (branch, expires_at desc);

alter table public.qr_sessions enable row level security;

drop policy if exists "members read qr sessions" on public.qr_sessions;
create policy "members read qr sessions" on public.qr_sessions
  for select using (auth.uid() is not null);

drop policy if exists "admins manage qr sessions" on public.qr_sessions;
create policy "admins manage qr sessions" on public.qr_sessions
  for all
  using (public.my_role() = 'superAdmin'
      or (public.my_role() = 'admin' and branch = public.my_branch()))
  with check (public.my_role() = 'superAdmin'
      or (public.my_role() = 'admin' and branch = public.my_branch()));

-- ===== Extend attendance with check-in metadata =====
alter table public.attendance
  add column if not exists checked_in_at   timestamptz,
  add column if not exists checked_in_lat  double precision,
  add column if not exists checked_in_lng  double precision,
  add column if not exists via             text,    -- 'manual' | 'qr'
  add column if not exists qr_session_id   uuid
    references public.qr_sessions(id) on delete set null;

-- ===== claim_attendance RPC =====
-- Called by the member's app right after a successful QR scan.
-- Returns json: { ok, late_minutes, session_id, checked_in_at } or
-- raises with a human-readable message.
create or replace function public.claim_attendance(
  p_token text,
  p_lat   double precision default null,
  p_lng   double precision default null
) returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id      uuid := auth.uid();
  v_session      public.qr_sessions%rowtype;
  v_now          timestamptz := now();
  v_late_minutes int := 0;
  v_existing     public.attendance%rowtype;
begin
  if v_user_id is null then
    raise exception 'You must be signed in to check in';
  end if;

  select * into v_session from public.qr_sessions where token = p_token;
  if not found then
    raise exception 'Invalid QR code';
  end if;
  if v_now > v_session.expires_at then
    raise exception 'This QR code has expired';
  end if;

  -- Late computation: minutes between threshold and the scan.
  if v_session.late_after is not null and v_now > v_session.late_after then
    v_late_minutes := greatest(
      0,
      (extract(epoch from (v_now - v_session.late_after)) / 60)::int
    );
  end if;

  -- Reject duplicate scans for this rehearsal.
  select * into v_existing
    from public.attendance
   where rehearsal_id = v_session.rehearsal_id
     and member_id    = v_user_id;
  if found and v_existing.present and v_existing.via = 'qr' then
    raise exception 'You already checked in for this session';
  end if;

  insert into public.attendance (
    rehearsal_id, member_id, present, late_minutes,
    checked_in_at, checked_in_lat, checked_in_lng,
    via, qr_session_id
  ) values (
    v_session.rehearsal_id, v_user_id, true, v_late_minutes,
    v_now, p_lat, p_lng,
    'qr', v_session.id
  )
  on conflict (rehearsal_id, member_id) do update set
    present       = true,
    late_minutes  = excluded.late_minutes,
    checked_in_at = excluded.checked_in_at,
    checked_in_lat= excluded.checked_in_lat,
    checked_in_lng= excluded.checked_in_lng,
    via           = excluded.via,
    qr_session_id = excluded.qr_session_id;

  return json_build_object(
    'ok',            true,
    'late_minutes',  v_late_minutes,
    'session_id',    v_session.id,
    'checked_in_at', v_now
  );
end $$;

grant execute on function public.claim_attendance(text, double precision, double precision)
  to authenticated;
