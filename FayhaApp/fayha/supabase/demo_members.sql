-- ============================================================
-- Fayha — 3 demo members (Amir, Roy, Adam). Password: 123456
-- Run once in the Supabase SQL Editor. Safe to re-run.
-- ============================================================

-- Clean any previous attempt (cascades to members).
delete from auth.users where email in ('amir@gmail.com','roy@gmail.com','adam@gmail.com');

do $$
declare
  amir_id uuid := gen_random_uuid();
  roy_id  uuid := gen_random_uuid();
  adam_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change)
  values
    ('00000000-0000-0000-0000-000000000000', amir_id, 'authenticated', 'authenticated',
     'amir@gmail.com', crypt('123456', gen_salt('bf')), now(), now(), now(),
     '{"provider":"email","providers":["email"]}'::jsonb,
     '{"name":"Amir Chehayeb","phone":"+96170111222","branch":"Beirut","voice_section":"Bass 1"}'::jsonb,
     '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', roy_id, 'authenticated', 'authenticated',
     'roy@gmail.com', crypt('123456', gen_salt('bf')), now(), now(), now(),
     '{"provider":"email","providers":["email"]}'::jsonb,
     '{"name":"Roy Bilain","phone":"+96171237881","branch":"Tripoli","voice_section":"Tenor 2"}'::jsonb,
     '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', adam_id, 'authenticated', 'authenticated',
     'adam@gmail.com', crypt('123456', gen_salt('bf')), now(), now(), now(),
     '{"provider":"email","providers":["email"]}'::jsonb,
     '{"name":"Adam Khoury","phone":"+96176333444","branch":"Aley","voice_section":"Tenor 1"}'::jsonb,
     '', '', '', '');

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id, created_at, updated_at)
  values
    (gen_random_uuid(), amir_id,
     jsonb_build_object('sub', amir_id::text, 'email', 'amir@gmail.com'),
     'email', amir_id::text, now(), now()),
    (gen_random_uuid(), roy_id,
     jsonb_build_object('sub', roy_id::text, 'email', 'roy@gmail.com'),
     'email', roy_id::text, now(), now()),
    (gen_random_uuid(), adam_id,
     jsonb_build_object('sub', adam_id::text, 'email', 'adam@gmail.com'),
     'email', adam_id::text, now(), now());
end $$;

-- Activate the member rows (the trigger created them as 'pending') + demo data.
update public.members set
  status = 'active', join_date = '2021-04-01', concerts_count = 38,
  practice_hours = 420, travels_count = 3,
  travel_locations = array['Istanbul, Turkey','Doha, Qatar','Damascus, Syria']
where email = 'amir@gmail.com';

update public.members set
  status = 'active', join_date = '2019-09-12', concerts_count = 64,
  practice_hours = 760, travels_count = 5,
  travel_locations = array['Istanbul, Turkey','Doha, Qatar','AlUla, Saudi Arabia',
    'Damascus, Syria','Cairo, Egypt']
where email = 'roy@gmail.com';

update public.members set
  status = 'active', join_date = '2024-02-10', concerts_count = 6,
  practice_hours = 90, travels_count = 0
where email = 'adam@gmail.com';
