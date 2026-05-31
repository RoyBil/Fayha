-- ============================================================
-- Fayha National Choir — FULL DATABASE SCHEMA
-- ------------------------------------------------------------
-- The live Supabase project is already set up from this.
-- This single file is the canonical record — run it top to
-- bottom on a fresh Supabase project to rebuild everything.
-- Before running on a fresh project: Authentication → Email →
-- turn OFF "Confirm email".
-- ============================================================


-- ============================================================
-- 1. MEMBERS  (created first — functions and FKs depend on it)
-- ============================================================
create table if not exists public.members (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  phone text,
  photo_url text,
  branch text not null default 'Tripoli',
  voice_section text not null default 'Soprano',
  role text not null default 'member',      -- member | admin | superAdmin
  status text not null default 'pending',   -- pending | active | deactivated | left
  join_date date default current_date,
  favorite_song_id text,
  least_favorite_song_id text,
  share_location boolean default true,
  concerts_count int default 0,
  practice_hours numeric default 0,
  travels_count int default 0,
  travel_locations text[] default '{}',
  is_returning boolean default false,
  break_from date,
  break_to date,
  clothing jsonb default '[]'::jsonb,
  house_lat double precision,
  house_lng double precision,
  house_address text,
  created_at timestamptz default now()
);

alter table public.members enable row level security;

-- Helper functions (security definer = no RLS recursion)
create or replace function public.my_role()
returns text language sql security definer stable
as $$ select role from public.members where id = auth.uid() $$;

create or replace function public.my_status()
returns text language sql security definer stable
as $$ select status from public.members where id = auth.uid() $$;

create or replace function public.my_branch()
returns text language sql security definer stable
as $$ select branch from public.members where id = auth.uid() $$;

-- members RLS
drop policy if exists "read own member row" on public.members;
create policy "read own member row" on public.members
  for select using (auth.uid() = id);

drop policy if exists "admins read all members" on public.members;
create policy "admins read all members" on public.members
  for select using (public.my_role() in ('admin', 'superAdmin'));

drop policy if exists "update own member row" on public.members;
create policy "update own member row" on public.members
  for update using (auth.uid() = id);

-- Only the super admin (Maestro) may change another member's status/role.
drop policy if exists "superadmin updates members" on public.members;
create policy "superadmin updates members" on public.members
  for update using (public.my_role() = 'superAdmin');

-- Auto-create a members row on signup. The Maestro's email is
-- bootstrapped as a fully set-up superAdmin founder account.
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
            'Amman, Jordan', 'Dubai, UAE', 'Muscat, Oman']::text[]
         else coalesce(
            case when jsonb_typeof(new.raw_user_meta_data->'travel_locations') = 'array'
                 then array(select jsonb_array_elements_text(
                        new.raw_user_meta_data->'travel_locations'))
                 else null end, '{}'::text[]) end,
    case when is_maestro then false
         else coalesce(nullif(new.raw_user_meta_data->>'is_returning', '')::boolean, false) end,
    case when is_maestro then null
         else nullif(new.raw_user_meta_data->>'break_from', '')::date end,
    case when is_maestro then null
         else nullif(new.raw_user_meta_data->>'break_to', '')::date end,
    case when jsonb_typeof(new.raw_user_meta_data->'clothing') = 'array'
         then new.raw_user_meta_data->'clothing' else '[]'::jsonb end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ============================================================
-- 2. AUDIENCE CONTENT TABLES  (public read; admin write where noted)
-- ============================================================

-- ---- Concerts ----
create table if not exists public.concerts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  location text not null,
  starts_at timestamptz not null,
  created_at timestamptz default now()
);
alter table public.concerts enable row level security;
drop policy if exists "Concerts are publicly readable" on public.concerts;
create policy "Concerts are publicly readable" on public.concerts
  for select using (true);

-- ---- News posts ----
create table if not exists public.news_posts (
  id uuid primary key default gen_random_uuid(),
  date_label text not null,
  title text not null,
  body text not null,
  sort_date timestamptz not null,
  created_at timestamptz default now()
);
alter table public.news_posts enable row level security;
drop policy if exists "News are publicly readable" on public.news_posts;
create policy "News are publicly readable" on public.news_posts
  for select using (true);
drop policy if exists "admins manage news" on public.news_posts;
create policy "admins manage news" on public.news_posts
  for all using (public.my_role() in ('admin', 'superAdmin'))
  with check (public.my_role() in ('admin', 'superAdmin'));

-- ---- Songs ----
create table if not exists public.songs (
  id text primary key,
  title text not null,
  subtitle text,
  composers text,
  description text,
  lyrics text,
  youtube_url text,
  sort_order int default 0,
  created_at timestamptz default now()
);
alter table public.songs enable row level security;
drop policy if exists "Songs are publicly readable" on public.songs;
create policy "Songs are publicly readable" on public.songs
  for select using (true);
drop policy if exists "admins manage songs" on public.songs;
create policy "admins manage songs" on public.songs
  for all using (public.my_role() in ('admin', 'superAdmin'))
  with check (public.my_role() in ('admin', 'superAdmin'));

-- ---- Branches ----
create table if not exists public.branches (
  id text primary key,
  name text not null,
  practice_location text not null,
  map_url text,
  lat double precision not null,
  lng double precision not null,
  year_opened int,
  conductor text,
  members_approx int,
  rehearsal_schedule text,
  description text,
  sort_order int default 0
);
alter table public.branches enable row level security;
drop policy if exists "Branches are publicly readable" on public.branches;
create policy "Branches are publicly readable" on public.branches
  for select using (true);

-- ---- Venues ----
create table if not exists public.venues (
  id uuid primary key default gen_random_uuid(),
  city text not null,
  country text not null,
  date_label text not null,
  performed_at date not null,
  lat double precision not null,
  lng double precision not null,
  event text,
  notes text
);
alter table public.venues enable row level security;
drop policy if exists "Venues are publicly readable" on public.venues;
create policy "Venues are publicly readable" on public.venues
  for select using (true);

-- ---- Trained choirs ----
create table if not exists public.trained_choirs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text not null,
  period text not null,
  conductor text not null,
  note text,
  instagram_url text,
  sort_order int default 0
);
alter table public.trained_choirs enable row level security;
drop policy if exists "Trained choirs are publicly readable" on public.trained_choirs;
create policy "Trained choirs are publicly readable" on public.trained_choirs
  for select using (true);

-- ---- Achievements ----
create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  year int not null,
  title text not null,
  event text not null,
  sort_order int default 0
);
alter table public.achievements enable row level security;
drop policy if exists "Achievements are publicly readable" on public.achievements;
create policy "Achievements are publicly readable" on public.achievements
  for select using (true);

-- ---- Social projects ----
create table if not exists public.social_projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  period text not null,
  description text not null,
  sort_order int default 0
);
alter table public.social_projects enable row level security;
drop policy if exists "Social projects are publicly readable" on public.social_projects;
create policy "Social projects are publicly readable" on public.social_projects
  for select using (true);

-- ---- Testimonials ----
create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  author text not null,
  voice_section text,
  body text not null,
  status text not null default 'pending',  -- pending | approved | rejected
  submitted_at timestamptz default now()
);
alter table public.testimonials enable row level security;
drop policy if exists "Approved testimonials are publicly readable" on public.testimonials;
create policy "Approved testimonials are publicly readable" on public.testimonials
  for select using (status = 'approved');
drop policy if exists "Anyone can submit a testimonial" on public.testimonials;
create policy "Anyone can submit a testimonial" on public.testimonials
  for insert with check (true);

-- ---- Social posts ----
create table if not exists public.social_posts (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  author text not null,
  body text not null,
  posted_label text not null,
  posted_at timestamptz default now()
);
alter table public.social_posts enable row level security;
drop policy if exists "Social posts are publicly readable" on public.social_posts;
create policy "Social posts are publicly readable" on public.social_posts
  for select using (true);

-- ---- Newsletter ----
create table if not exists public.newsletter_subscriptions (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  subscribed_at timestamptz default now()
);
alter table public.newsletter_subscriptions enable row level security;
drop policy if exists "Anyone can subscribe to newsletter" on public.newsletter_subscriptions;
create policy "Anyone can subscribe to newsletter" on public.newsletter_subscriptions
  for insert with check (true);


-- ============================================================
-- 3. MESSAGES  (admin announcements with audience targeting)
-- ============================================================
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience text not null,   -- everyone | audience | members | admins | superAdmins | branch
  branch text,
  sender_id uuid references public.members(id) on delete set null,
  sender_name text,
  created_at timestamptz default now()
);
alter table public.messages enable row level security;

drop policy if exists "read messages by audience" on public.messages;
create policy "read messages by audience" on public.messages
  for select using (
    audience in ('everyone', 'audience')
    or (audience = 'members'     and auth.uid() is not null)
    or (audience = 'admins'      and public.my_role() in ('admin', 'superAdmin'))
    or (audience = 'superAdmins' and public.my_role() = 'superAdmin')
    or (audience = 'branch'      and (branch = public.my_branch()
                                      or public.my_role() in ('admin', 'superAdmin')))
  );
drop policy if exists "admins send messages" on public.messages;
create policy "admins send messages" on public.messages
  for insert with check (public.my_role() in ('admin', 'superAdmin'));
drop policy if exists "admins delete messages" on public.messages;
create policy "admins delete messages" on public.messages
  for delete using (public.my_role() in ('admin', 'superAdmin'));


-- ============================================================
-- 4. ATTENDANCE  (admin per branch; super admin any branch)
-- ============================================================
create table if not exists public.rehearsals (
  id uuid primary key default gen_random_uuid(),
  branch text not null,
  session_date date not null,
  status text not null default 'held',   -- held | cancelled
  recorded_by uuid references public.members(id) on delete set null,
  recorded_by_name text,
  recorded_at timestamptz default now(),
  created_at timestamptz default now(),
  unique (branch, session_date)
);
alter table public.rehearsals enable row level security;
drop policy if exists "members read rehearsals" on public.rehearsals;
create policy "members read rehearsals" on public.rehearsals
  for select using (auth.uid() is not null);
drop policy if exists "admins write rehearsals" on public.rehearsals;
create policy "admins write rehearsals" on public.rehearsals
  for all
  using (public.my_role() = 'superAdmin'
         or (public.my_role() = 'admin' and branch = public.my_branch()))
  with check (public.my_role() = 'superAdmin'
         or (public.my_role() = 'admin' and branch = public.my_branch()));

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  rehearsal_id uuid not null references public.rehearsals(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  present boolean not null default false,
  unique (rehearsal_id, member_id)
);
alter table public.attendance enable row level security;
drop policy if exists "members read attendance" on public.attendance;
create policy "members read attendance" on public.attendance
  for select using (auth.uid() is not null);
drop policy if exists "admins write attendance" on public.attendance;
create policy "admins write attendance" on public.attendance
  for all
  using (exists (select 1 from public.rehearsals r
                 where r.id = rehearsal_id
                   and (public.my_role() = 'superAdmin'
                        or (public.my_role() = 'admin'
                            and r.branch = public.my_branch()))))
  with check (exists (select 1 from public.rehearsals r
                 where r.id = rehearsal_id
                   and (public.my_role() = 'superAdmin'
                        or (public.my_role() = 'admin'
                            and r.branch = public.my_branch()))));


-- ============================================================
-- 5. SEED CONTENT  (audience data — skip if data already exists)
-- ============================================================

insert into public.concerts (title, description, location, starts_at) values
  ('Spring Recital', 'An evening of Arabic a cappella classics, featuring guest soloists.',
   'Al Madina Theatre, Beirut', '2026-06-14 20:00:00+03'),
  ('Angham w Salam Community Concert', 'A nationwide community choir performance, 200+ voices on stage.',
   'Cultural Center, Tripoli', '2026-07-05 19:30:00+03')
on conflict do nothing;

insert into public.news_posts (date_label, title, body, sort_date) values
  ('2025', 'Study Tour with the European Choral Association',
   'In collaboration with the European Choral Association, the choir organized a study tour to Lebanon — welcoming conductors and choral leaders to engage in artistic exchange, workshops on Arabic music, and a culturally immersive experience.',
   '2025-06-01'),
  ('2023, Istanbul', 'World Symposium on Choral Music',
   'Fayha National Choir performed at the World Symposium on Choral Music in Istanbul, organized by the International Federation for Choral Music.',
   '2023-04-01'),
  ('2022', 'First Lebanese National Choir',
   'Having established branches in Beirut, Aley, and Chouf — in addition to its original Tripoli home — the choir was designated the first Lebanese National Choir.',
   '2022-01-01')
on conflict do nothing;

insert into public.songs (id, title, subtitle, composers, description, lyrics, youtube_url, sort_order) values
  ('zahrat', 'Zahrat Al Madaen', 'The Rose of Cities', 'Rahbani Brothers · Arr. Edward Torikian',
   'A tribute to the Palestinian cause and the peace that must come, presented as a journey through the different mosques and churches of Jerusalem, the rose of all cities.',
   E'لأجلك يا مدينة الصلاة أصلي\nلأجلك يا بهية المساكن يا زهرة المدائن',
   'https://youtu.be/6IIaNAGL2as', 1),
  ('ahdafi', 'Ahdafi', 'My Goals', 'Nizar Hindi · Hani Siblini',
   'The 17 Sustainable Development Goals of the UN''s 2030 agenda presented as a choral piece emphasizing the collective voice.',
   E'أهدافي السبعة عشر\nنحو غدٍ أكثر عدلاً وأماناً',
   'https://youtu.be/A5cW2hefuMY', 2),
  ('asmaa', 'Asmaa Allah Al Husna', 'The 99 Names of God', 'Islamic Heritage · Arr. Edward Torikian',
   'An a cappella prayer reciting the 99 holy names of God in the Islamic faith.',
   E'هو الله الذي لا إله إلا هو\nالرحمن الرحيم، الملك القدوس',
   'https://youtu.be/gAArwqnML8s', 3),
  ('an_tuhibba', 'An Tuhibba', 'To Love', 'Arabic Traditional · Arr. Edward Torikian',
   'A meditation on love that asks listeners to live twice.',
   E'أن تحبَّ يعني أن تعيشَ مرتين', null, 4),
  ('immi_namit', 'Immi Namit', 'My Mother Has Slept', 'Lebanese Folk · Arr. Edward Torikian',
   'A tender lullaby drawn from the Lebanese folk tradition.',
   E'إمّي نامت، نامت بلا غناء', null, 5),
  ('fog_el_nakhel', 'Fog El Nakhel', 'Above the Palm Trees', 'Iraqi Traditional · Arr. Edward Torikian',
   'A celebrated Iraqi folk arrangement, full of longing and warmth.',
   E'فوق النخل فوق يابا فوق النخل فوق', null, 6)
on conflict do nothing;

insert into public.branches (id, name, practice_location, map_url, lat, lng, year_opened, conductor, members_approx, rehearsal_schedule, description, sort_order) values
  ('tripoli', 'Tripoli', 'Mina, Tripoli', 'https://maps.app.goo.gl/4hnRQwq9reAvGjfz6',
   34.4534215, 35.8145463, 2003, 'Maestro Barkev Taslakian', 60, 'Thu · Fri · Sat — 6:00–9:00 PM',
   'The founding branch, established in 2003 — it gave the choir its name.', 1),
  ('beirut', 'Beirut', 'American University of Beirut (AUB)', 'https://maps.app.goo.gl/n5GwmvnWTEfXaHn38',
   33.9024626, 35.4821829, 2015, 'Maestro Barkev Taslakian', 50, 'Mon · Tue · Wed — 6:00–9:00 PM',
   'Hosted at AUB''s historic campus.', 2),
  ('aley', 'Aley', 'Aley', 'https://maps.app.goo.gl/jNeMQbe1MdiLv8Ys9',
   33.8027187, 35.6095478, 2022, 'Section conductor', 25, 'Wed · Thu · Fri — 6:00–9:00 PM',
   'Opened in 2022 during the nationwide expansion.', 3),
  ('chouf', 'Chouf', 'Chouf', 'https://maps.app.goo.gl/ZCHSTUepHB87MQVdA',
   33.6712154, 35.5997846, 2022, 'Section conductor', 20, 'Mon · Tue · Wed — 6:00–9:00 PM',
   'Brings collective singing to the mountains south-east of Beirut.', 4)
on conflict do nothing;

insert into public.venues (city, country, date_label, performed_at, lat, lng, event, notes) values
  ('AlUla', 'Saudi Arabia', 'April 2025', '2025-04-01', 26.6087, 37.9226, 'Heritage Concert',
   'Performance in the UNESCO World Heritage site of AlUla.'),
  ('Doha', 'Qatar', 'December 2024', '2024-12-01', 25.2854, 51.5310, 'Doha Cultural Festival',
   'Invited performance of Arabic classics.'),
  ('Damascus', 'Syria', 'June 2023', '2023-06-01', 33.5138, 36.2765, 'Solidarity Concert',
   'Celebrating shared Arabic musical heritage.'),
  ('Istanbul', 'Turkey', 'April 2023', '2023-04-01', 41.0082, 28.9784, 'World Symposium on Choral Music',
   'Invited choir at the IFCM World Symposium.')
on conflict do nothing;

insert into public.trained_choirs (name, location, period, conductor, note, instagram_url, sort_order) values
  ('Maqam Choir', 'Bekaa, Lebanon', '2023 – Present', 'George Faraj',
   'Studied within a Fayha social project and started his own choir.',
   'https://www.instagram.com/maqam.choir/', 1),
  ('Shaghaf Choir', 'Cairo, Egypt', '2024 – Present', 'Islam Saeed',
   'Overseen by Fayha National Choir.', 'https://www.instagram.com/shaghaf_choir/', 2),
  ('Najd Choir', 'Riyadh, Saudi Arabia', '2019 – Present', 'Adnan Rachid',
   'A previous student and member at Fayha.', 'https://www.instagram.com/najdchoir_official/', 3),
  ('Nagham Choir', 'Tripoli, Lebanon', '2019 – 2022', 'Mahmoud Mawwas',
   'An assistant conductor at Fayha.', 'https://www.instagram.com/naghamchoir/', 4),
  ('Fan Choir', 'Saida, Lebanon', '2022 – 2024', 'Roudy Francis',
   'Studied within a Fayha social project and started his own choir.',
   'https://www.instagram.com/fanchoirsaida/', 5)
on conflict do nothing;

insert into public.achievements (year, title, event, sort_order) values
  (2007, '1st Prize, Mixed Adult Choirs', 'Warsaw International Choir Festival', 1),
  (2005, '2nd Prize, Mixed Adult Choirs', 'Warsaw International Choir Festival', 2),
  (2023, 'Invited Choir', 'World Symposium on Choral Music (IFCM)', 3),
  (2016, '1st Prize', 'ChoirFest Middle East', 4),
  (2018, '2nd Prize', 'ChoirFest Middle East', 5),
  (2016, '1st Prize', '"Music and the Sea", International Festival, Greece', 6),
  (2015, 'Music Rights Award', 'International Music Council', 7)
on conflict do nothing;

insert into public.social_projects (name, period, description, sort_order) values
  ('UNESCO Choir', '2009 – 2013',
   'With the UNESCO regional office. Targeted 10,000+ marginalized students in public schools.', 1),
  ('Lebanese Palestinian Chamber Choir', '2009 – 2011',
   'With UNDP. Refostered peaceful relations around the Nahr El Bared camp.', 2),
  ('Sonbula Choir', '2014 – 2022',
   'With the Sonbula Association for Syrian Refugees, funded by Nai Association, Austria.', 3),
  ('Angham w Salam Choir', '2022 – Present',
   'With UNDP, funded by KFW. A nationwide community choir, 150 members, four branches.', 4)
on conflict do nothing;

insert into public.testimonials (author, voice_section, body, status) values
  ('Nour Khoury', 'Soprano',
   'Fayha has become my second family. Every rehearsal, every concert — I leave feeling lifted.',
   'approved'),
  ('Karim Saade', 'Bass 1',
   'Joining the choir was the best decision I made. The musical depth and friendship shaped me.',
   'approved')
on conflict do nothing;

insert into public.social_posts (platform, author, body, posted_label, posted_at) values
  ('Instagram', '@fayhachoir', 'Tonight in Tripoli — full house, full hearts.',
   '2 days ago', now() - interval '2 days'),
  ('Facebook', 'Fayha National Choir', 'Behind the scenes from the Angham w Salam rehearsal.',
   '5 days ago', now() - interval '5 days'),
  ('Instagram', '@fayhachoir', 'Workshop with the European Choral Association.',
   '2 weeks ago', now() - interval '14 days')
on conflict do nothing;

-- ============================================================
-- End of schema. The Maestro signs up via the app with
-- maestro@fayhanationalchoir.com — the trigger sets him up.
-- ============================================================
