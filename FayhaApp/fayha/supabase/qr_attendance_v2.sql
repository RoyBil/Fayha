-- ============================================================
-- Fayha — QR attendance v2
-- 1. The admin picks WHEN the QR becomes active (`valid_from`) and
--    HOW LONG it stays valid (`expires_at`), instead of "now + 3h".
-- 2. The QR can be attached to a CONCERT or BIG REHEARSAL too, not
--    just a weekly rehearsal date. attendance rows now carry either
--    a rehearsal_id OR a concert_id.
-- ============================================================

-- ===== qr_sessions: support concerts + scheduled start =====

alter table public.qr_sessions
  add column if not exists valid_from timestamptz not null default now(),
  add column if not exists concert_id uuid
    references public.concerts(id) on delete cascade;

alter table public.qr_sessions
  alter column rehearsal_id drop not null,
  alter column branch       drop not null;

-- Exactly one target.
alter table public.qr_sessions
  drop constraint if exists qr_sessions_one_target;
alter table public.qr_sessions
  add constraint qr_sessions_one_target check (
    (rehearsal_id is not null and concert_id is null) or
    (rehearsal_id is null and concert_id is not null)
  );

create index if not exists qr_sessions_concert_idx
  on public.qr_sessions (concert_id);

-- Reopen RLS to admins of the concert as well as branch admins.
drop policy if exists "admins manage qr sessions" on public.qr_sessions;
create policy "admins manage qr sessions" on public.qr_sessions
  for all
  using (
    public.my_role() = 'superAdmin'
    or (rehearsal_id is not null
        and public.my_role() = 'admin'
        and branch = public.my_branch())
    or (concert_id is not null
        and public.my_role() in ('admin', 'superAdmin'))
  )
  with check (
    public.my_role() = 'superAdmin'
    or (rehearsal_id is not null
        and public.my_role() = 'admin'
        and branch = public.my_branch())
    or (concert_id is not null
        and public.my_role() in ('admin', 'superAdmin'))
  );

-- ===== attendance: support concerts =====

alter table public.attendance
  add column if not exists concert_id uuid
    references public.concerts(id) on delete cascade;
alter table public.attendance
  alter column rehearsal_id drop not null;

alter table public.attendance
  drop constraint if exists attendance_one_target;
alter table public.attendance
  add constraint attendance_one_target check (
    (rehearsal_id is not null and concert_id is null) or
    (rehearsal_id is null and concert_id is not null)
  );

-- Replace the old (rehearsal_id, member_id) unique key with two
-- partial unique indexes — one per target type.
alter table public.attendance
  drop constraint if exists attendance_rehearsal_id_member_id_key;
create unique index if not exists attendance_unique_rehearsal_member
  on public.attendance (rehearsal_id, member_id)
  where rehearsal_id is not null;
create unique index if not exists attendance_unique_concert_member
  on public.attendance (concert_id, member_id)
  where concert_id is not null;

-- ===== claim_attendance RPC: handle both targets + valid_from =====

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
  if v_now < v_session.valid_from then
    raise exception 'This QR is not active yet';
  end if;
  if v_now > v_session.expires_at then
    raise exception 'This QR code has expired';
  end if;

  if v_session.late_after is not null and v_now > v_session.late_after then
    v_late_minutes := greatest(
      0,
      (extract(epoch from (v_now - v_session.late_after)) / 60)::int
    );
  end if;

  -- Look up an existing attendance row for either target.
  if v_session.rehearsal_id is not null then
    select * into v_existing
      from public.attendance
     where rehearsal_id = v_session.rehearsal_id
       and member_id    = v_user_id;
  else
    select * into v_existing
      from public.attendance
     where concert_id = v_session.concert_id
       and member_id  = v_user_id;
  end if;
  if found and v_existing.present and v_existing.via = 'qr' then
    raise exception 'You already checked in for this session';
  end if;

  if v_session.rehearsal_id is not null then
    insert into public.attendance (
      rehearsal_id, member_id, present, late_minutes,
      checked_in_at, checked_in_lat, checked_in_lng,
      via, qr_session_id
    ) values (
      v_session.rehearsal_id, v_user_id, true, v_late_minutes,
      v_now, p_lat, p_lng, 'qr', v_session.id
    )
    on conflict (rehearsal_id, member_id) do update set
      present       = true,
      late_minutes  = excluded.late_minutes,
      checked_in_at = excluded.checked_in_at,
      checked_in_lat= excluded.checked_in_lat,
      checked_in_lng= excluded.checked_in_lng,
      via           = excluded.via,
      qr_session_id = excluded.qr_session_id;
  else
    insert into public.attendance (
      concert_id, member_id, present, late_minutes,
      checked_in_at, checked_in_lat, checked_in_lng,
      via, qr_session_id
    ) values (
      v_session.concert_id, v_user_id, true, v_late_minutes,
      v_now, p_lat, p_lng, 'qr', v_session.id
    )
    on conflict (concert_id, member_id) do update set
      present       = true,
      late_minutes  = excluded.late_minutes,
      checked_in_at = excluded.checked_in_at,
      checked_in_lat= excluded.checked_in_lat,
      checked_in_lng= excluded.checked_in_lng,
      via           = excluded.via,
      qr_session_id = excluded.qr_session_id;
  end if;

  return json_build_object(
    'ok',            true,
    'late_minutes',  v_late_minutes,
    'session_id',    v_session.id,
    'checked_in_at', v_now
  );
end $$;

grant execute on function public.claim_attendance(text, double precision, double precision)
  to authenticated;
