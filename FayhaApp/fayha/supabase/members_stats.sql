-- ============================================================
-- Fayha — Member history & stats (returning members)
-- Run once in the Supabase SQL Editor, AFTER members.sql.
-- ============================================================

alter table public.members add column if not exists concerts_count int default 0;
alter table public.members add column if not exists practice_hours numeric default 0;
alter table public.members add column if not exists travels_count int default 0;
alter table public.members add column if not exists is_returning boolean default false;
alter table public.members add column if not exists break_from date;
alter table public.members add column if not exists break_to date;

-- Rebuild the signup trigger to capture the new fields from sign-up metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
as $$
begin
  insert into public.members (
    id, name, email, phone, branch, voice_section, role, status,
    join_date, concerts_count, practice_hours, travels_count,
    is_returning, break_from, break_to
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'New Member'),
    new.email,
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'branch', 'Tripoli'),
    coalesce(new.raw_user_meta_data->>'voice_section', 'Soprano'),
    case when new.email = 'maestro@fayhanationalchoir.com'
         then 'superAdmin' else 'member' end,
    case when new.email = 'maestro@fayhanationalchoir.com'
         then 'active' else 'pending' end,
    coalesce(nullif(new.raw_user_meta_data->>'join_date', '')::date, current_date),
    coalesce(nullif(new.raw_user_meta_data->>'concerts_count', '')::int, 0),
    coalesce(nullif(new.raw_user_meta_data->>'practice_hours', '')::numeric, 0),
    coalesce(nullif(new.raw_user_meta_data->>'travels_count', '')::int, 0),
    coalesce(nullif(new.raw_user_meta_data->>'is_returning', '')::boolean, false),
    nullif(new.raw_user_meta_data->>'break_from', '')::date,
    nullif(new.raw_user_meta_data->>'break_to', '')::date
  );
  return new;
end;
$$;
