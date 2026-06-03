-- Late tracking on attendance: how many minutes the member arrived
-- late by. NULL or 0 = on time / not late.
alter table public.attendance
  add column if not exists late_minutes int;
