-- ============================================================
-- Fayha — Member clothing inventory
-- Run once in the Supabase SQL Editor, AFTER maestro_setup.sql.
-- ============================================================

alter table public.members
  add column if not exists clothing jsonb default '[]'::jsonb;

-- Rebuild the signup trigger to also store the clothing list.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
as $$
declare
  is_maestro boolean := new.email = 'maestro@fayhanationalchoir.com';
begin
  insert into public.members (
    id, name, email, phone, branch, voice_section, role, status,
    join_date, concerts_count, practice_hours, travels_count,
    travel_locations, is_returning, break_from, break_to, clothing
  )
  values (
    new.id,
    case when is_maestro then 'Barkev Taslakian'
         else coalesce(new.raw_user_meta_data->>'name', 'New Member') end,
    new.email,
    case when is_maestro then '+96176330323'
         else new.raw_user_meta_data->>'phone' end,
    case when is_maestro then 'All Branches'
         else coalesce(new.raw_user_meta_data->>'branch', 'Tripoli') end,
    case when is_maestro then 'Conductor'
         else coalesce(new.raw_user_meta_data->>'voice_section', 'Soprano') end,
    case when is_maestro then 'superAdmin' else 'member' end,
    case when is_maestro then 'active' else 'pending' end,
    case when is_maestro then date '2003-03-01'
         else coalesce(nullif(new.raw_user_meta_data->>'join_date', '')::date,
                       current_date) end,
    case when is_maestro then 320
         else coalesce(nullif(new.raw_user_meta_data->>'concerts_count', '')::int, 0) end,
    case when is_maestro then 6000
         else coalesce(nullif(new.raw_user_meta_data->>'practice_hours', '')::numeric, 0) end,
    case when is_maestro then 12
         else coalesce(nullif(new.raw_user_meta_data->>'travels_count', '')::int, 0) end,
    case when is_maestro then array[
            'Warsaw, Poland', 'Athens, Greece', 'Istanbul, Turkey',
            'Damascus, Syria', 'Doha, Qatar', 'AlUla, Saudi Arabia',
            'Cairo, Egypt', 'Beijing, China', 'Toronto, Canada',
            'Amman, Jordan', 'Dubai, UAE', 'Muscat, Oman'
         ]::text[]
         else coalesce(
            case when jsonb_typeof(new.raw_user_meta_data->'travel_locations') = 'array'
                 then array(select jsonb_array_elements_text(
                        new.raw_user_meta_data->'travel_locations'))
                 else null end,
            '{}'::text[]) end,
    case when is_maestro then false
         else coalesce(nullif(new.raw_user_meta_data->>'is_returning', '')::boolean, false) end,
    case when is_maestro then null
         else nullif(new.raw_user_meta_data->>'break_from', '')::date end,
    case when is_maestro then null
         else nullif(new.raw_user_meta_data->>'break_to', '')::date end,
    case when jsonb_typeof(new.raw_user_meta_data->'clothing') = 'array'
         then new.raw_user_meta_data->'clothing'
         else '[]'::jsonb end
  );
  return new;
end;
$$;
