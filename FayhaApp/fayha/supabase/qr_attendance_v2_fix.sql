-- Fix for: "there is no unique or exclusion constraint matching the
-- ON CONFLICT specification". The v2 migration replaced the old
-- (rehearsal_id, member_id) unique CONSTRAINT with PARTIAL unique
-- INDEXES (one for rehearsal_id, one for concert_id). Postgres
-- requires the predicate of a partial index in ON CONFLICT, OR a real
-- constraint. The old RPC used plain `on conflict (rehearsal_id,
-- member_id) ...` which no longer matches anything.
--
-- This rewrite avoids ON CONFLICT entirely: we check for an existing
-- attendance row, then update or insert. Same end behaviour, works
-- regardless of constraint/index shape.

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
  v_existing_id  uuid;
  v_existing_present boolean;
  v_existing_via text;
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

  -- Find an existing row for the right target.
  if v_session.rehearsal_id is not null then
    select id, present, via
      into v_existing_id, v_existing_present, v_existing_via
      from public.attendance
     where rehearsal_id = v_session.rehearsal_id
       and member_id    = v_user_id
     limit 1;
  else
    select id, present, via
      into v_existing_id, v_existing_present, v_existing_via
      from public.attendance
     where concert_id = v_session.concert_id
       and member_id  = v_user_id
     limit 1;
  end if;

  if v_existing_id is not null
     and v_existing_present
     and v_existing_via = 'qr' then
    raise exception 'You already checked in for this session';
  end if;

  if v_existing_id is not null then
    update public.attendance set
      present       = true,
      late_minutes  = v_late_minutes,
      checked_in_at = v_now,
      checked_in_lat= p_lat,
      checked_in_lng= p_lng,
      via           = 'qr',
      qr_session_id = v_session.id
    where id = v_existing_id;
  elsif v_session.rehearsal_id is not null then
    insert into public.attendance (
      rehearsal_id, member_id, present, late_minutes,
      checked_in_at, checked_in_lat, checked_in_lng,
      via, qr_session_id
    ) values (
      v_session.rehearsal_id, v_user_id, true, v_late_minutes,
      v_now, p_lat, p_lng, 'qr', v_session.id
    );
  else
    insert into public.attendance (
      concert_id, member_id, present, late_minutes,
      checked_in_at, checked_in_lat, checked_in_lng,
      via, qr_session_id
    ) values (
      v_session.concert_id, v_user_id, true, v_late_minutes,
      v_now, p_lat, p_lng, 'qr', v_session.id
    );
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
