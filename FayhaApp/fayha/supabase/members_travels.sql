-- ============================================================
-- Fayha — Travel locations for returning members
-- Run once in the Supabase SQL Editor, AFTER members_stats.sql.
-- ============================================================

alter table public.members
  add column if not exists travel_locations text[] default '{}';

-- Rebuild the signup trigger to also capture the travel locations list.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
as $$
begin
  insert into public.members (
    id, name, email, phone, branch, voice_section, role, status,
    join_date, concerts_count, practice_hours, travels_count,
    travel_locations, is_returning, break_from, break_to
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
    coalesce(
      case when jsonb_typeof(new.raw_user_meta_data->'travel_locations') = 'array'
           then array(select jsonb_array_elements_text(
                  new.raw_user_meta_data->'travel_locations'))
           else null end,
      '{}'::text[]
    ),
    coalesce(nullif(new.raw_user_meta_data->>'is_returning', '')::boolean, false),
    nullif(new.raw_user_meta_data->>'break_from', '')::date,
    nullif(new.raw_user_meta_data->>'break_to', '')::date
  );
  return new;
end;
$$;
