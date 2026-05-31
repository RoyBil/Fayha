-- ============================================================
-- Fayha National Choir — Audience tables
-- Run this once in the Supabase SQL Editor.
-- Concerts table is already created — only the rest below.
-- ============================================================

-- ============== NEWS POSTS ==============
create table if not exists public.news_posts (
  id uuid primary key default gen_random_uuid(),
  date_label text not null,
  title text not null,
  body text not null,
  sort_date timestamptz not null,
  created_at timestamptz default now()
);
alter table public.news_posts enable row level security;
create policy "News are publicly readable" on public.news_posts for select using (true);

insert into public.news_posts (date_label, title, body, sort_date) values
  ('2025', 'Study Tour with the European Choral Association',
   'In collaboration with the European Choral Association, the choir organized a study tour to Lebanon — welcoming conductors and choral leaders to engage in artistic exchange, workshops on Arabic music, and a culturally immersive experience.',
   '2025-06-01'),
  ('2023, Istanbul', 'World Symposium on Choral Music',
   'Fayha National Choir performed at the World Symposium on Choral Music in Istanbul, organized by the International Federation for Choral Music.',
   '2023-04-01'),
  ('2022', 'First Lebanese National Choir',
   'Having established branches in Beirut, Aley, and Chouf — in addition to its original Tripoli home — the choir was designated the first Lebanese National Choir.',
   '2022-01-01');

-- ============== SONGS ==============
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
create policy "Songs are publicly readable" on public.songs for select using (true);

insert into public.songs (id, title, subtitle, composers, description, lyrics, youtube_url, sort_order) values
  ('zahrat', 'Zahrat Al Madaen', 'The Rose of Cities', 'Rahbani Brothers · Arr. Edward Torikian',
   'A tribute to the Palestinian cause and the peace that must come, presented as a journey through the different mosques and churches of Jerusalem, the rose of all cities.',
   E'لأجلك يا مدينة الصلاة أصلي\nلأجلك يا بهية المساكن يا زهرة المدائن\nيا قدس، يا قدس، يا مدينة الصلاة أصلي',
   'https://youtu.be/6IIaNAGL2as', 1),
  ('ahdafi', 'Ahdafi', 'My Goals', 'Nizar Hindi · Hani Siblini',
   'The 17 Sustainable Development Goals of the UN''s 2030 agenda presented as a choral piece emphasizing the collective voice.',
   E'أهدافي السبعة عشر\nنحو غدٍ أكثر عدلاً وأماناً\nنزرع السلام، نُنهي الجوع',
   'https://youtu.be/A5cW2hefuMY', 2),
  ('asmaa', 'Asmaa Allah Al Husna', 'The 99 Names of God', 'Islamic Heritage · Arr. Edward Torikian',
   'An a cappella prayer reciting the 99 holy names of God in the Islamic faith.',
   E'هو الله الذي لا إله إلا هو\nالرحمن الرحيم، الملك القدوس',
   'https://youtu.be/gAArwqnML8s', 3),
  ('an_tuhibba', 'An Tuhibba', 'To Love', 'Arabic Traditional · Arr. Edward Torikian',
   'A meditation on love that asks listeners to live twice — once for themselves and once for the people they hold dear.',
   E'أن تحبَّ يعني أن تعيشَ مرتين\nأن تعرفَ بأنَّ الفجرَ آتٍ', null, 4),
  ('immi_namit', 'Immi Namit', 'My Mother Has Slept', 'Lebanese Folk · Arr. Edward Torikian',
   'A tender lullaby drawn from the Lebanese folk tradition.',
   E'إمّي نامت، نامت بلا غناء\nخلّيني أحلم، أحلم بالضياء', null, 5),
  ('fog_el_nakhel', 'Fog El Nakhel', 'Above the Palm Trees', 'Iraqi Traditional · Arr. Edward Torikian',
   'A celebrated Iraqi folk arrangement, full of longing and warmth.',
   E'فوق النخل فوق يابا فوق النخل فوق\nمدري لمع خدّه يابا مدري القمر فوق', null, 6);

-- ============== BRANCHES ==============
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
create policy "Branches are publicly readable" on public.branches for select using (true);

insert into public.branches (id, name, practice_location, map_url, lat, lng, year_opened, conductor, members_approx, rehearsal_schedule, description, sort_order) values
  ('tripoli', 'Tripoli', 'Mina, Tripoli', 'https://maps.app.goo.gl/4hnRQwq9reAvGjfz6',
   34.4534215, 35.8145463, 2003, 'Maestro Barkev Taslakian', 60, 'Weekly · Mondays & Wednesdays',
   'The founding branch. Established by Maestro Barkev Taslakian in 2003, it gave the choir its name — ''Fayha'' meaning fragrant, after the orange groves surrounding the city.', 1),
  ('beirut', 'Beirut', 'American University of Beirut (AUB)', 'https://maps.app.goo.gl/n5GwmvnWTEfXaHn38',
   33.9024626, 35.4821829, 2015, 'Maestro Barkev Taslakian', 50, 'Weekly · Tuesdays & Thursdays',
   'Hosted at AUB''s historic campus. The Beirut branch brought Fayha to the capital and helped expand the choir''s reach to a younger generation of singers.', 2),
  ('aley', 'Aley', 'Aley', 'https://maps.app.goo.gl/jNeMQbe1MdiLv8Ys9',
   33.8027187, 35.6095478, 2022, 'Section conductor', 25, 'Weekly · Saturdays',
   'Opened in 2022 as part of the nationwide expansion that earned Fayha its designation as the first Lebanese National Choir.', 3),
  ('chouf', 'Chouf', 'Chouf', 'https://maps.app.goo.gl/ZCHSTUepHB87MQVdA',
   33.6712154, 35.5997846, 2022, 'Section conductor', 20, 'Weekly · Saturdays',
   'The Chouf branch, opened alongside Aley in 2022, brings collective singing to the mountains south-east of Beirut.', 4);

-- ============== VENUES (places performed) ==============
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
create policy "Venues are publicly readable" on public.venues for select using (true);

insert into public.venues (city, country, date_label, performed_at, lat, lng, event, notes) values
  ('AlUla', 'Saudi Arabia', 'April 2025', '2025-04-01', 26.6087, 37.9226, 'Heritage Concert',
   'Performance in the UNESCO World Heritage site of AlUla, bringing Arabic a cappella to one of the region''s most iconic cultural landscapes.'),
  ('Doha', 'Qatar', 'December 2024', '2024-12-01', 25.2854, 51.5310, 'Doha Cultural Festival',
   'Invited performance featuring signature pieces from the choir''s repertoire of Arabic classics.'),
  ('Damascus', 'Syria', 'June 2023', '2023-06-01', 33.5138, 36.2765, 'Solidarity Concert',
   'Performance in Damascus celebrating shared Arabic musical heritage across the region.'),
  ('Istanbul', 'Turkey', 'April 2023', '2023-04-01', 41.0082, 28.9784, 'World Symposium on Choral Music',
   'Invited choir at the World Symposium on Choral Music, organized by the International Federation for Choral Music.');

-- ============== TRAINED CHOIRS ==============
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
create policy "Trained choirs are publicly readable" on public.trained_choirs for select using (true);

insert into public.trained_choirs (name, location, period, conductor, note, instagram_url, sort_order) values
  ('Maqam Choir', 'Bekaa, Lebanon', '2023 – Present', 'George Faraj',
   'Studied within one of the choir''s social projects and proceeded to start his own choir.',
   'https://www.instagram.com/maqam.choir/', 1),
  ('Shaghaf Choir', 'Cairo, Egypt', '2024 – Present', 'Islam Saeed',
   'Overseen by Fayha National Choir; conductor studies under Maestro Taslakian''s leadership.',
   'https://www.instagram.com/shaghaf_choir/', 2),
  ('Najd Choir', 'Riyadh, Saudi Arabia', '2019 – Present', 'Adnan Rachid',
   'A previous student and member at Fayha National Choir.',
   'https://www.instagram.com/najdchoir_official/', 3),
  ('Nagham Choir', 'Tripoli, Lebanon', '2019 – 2022', 'Mahmoud Mawwas',
   'An assistant conductor at Fayha National Choir.',
   'https://www.instagram.com/naghamchoir/', 4),
  ('Fan Choir', 'Saida, Lebanon', '2022 – 2024', 'Roudy Francis',
   'Studied within one of the choir''s social projects and proceeded to start his own choir.',
   'https://www.instagram.com/fanchoirsaida/', 5);

-- ============== ACHIEVEMENTS ==============
create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  year int not null,
  title text not null,
  event text not null,
  sort_order int default 0
);
alter table public.achievements enable row level security;
create policy "Achievements are publicly readable" on public.achievements for select using (true);

insert into public.achievements (year, title, event, sort_order) values
  (2007, '1st Prize, Mixed Adult Choirs', 'Warsaw International Choir Festival', 1),
  (2005, '2nd Prize, Mixed Adult Choirs', 'Warsaw International Choir Festival', 2),
  (2023, 'Invited Choir', 'World Symposium on Choral Music (IFCM)', 3),
  (2016, '1st Prize', 'ChoirFest Middle East', 4),
  (2018, '2nd Prize', 'ChoirFest Middle East', 5),
  (2016, '1st Prize', '"Music and the Sea", International Festival, Greece', 6),
  (2015, 'Music Rights Award', 'International Music Council', 7);

-- ============== SOCIAL PROJECTS ==============
create table if not exists public.social_projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  period text not null,
  description text not null,
  sort_order int default 0
);
alter table public.social_projects enable row level security;
create policy "Social projects are publicly readable" on public.social_projects for select using (true);

insert into public.social_projects (name, period, description, sort_order) values
  ('UNESCO Choir', '2009 – 2013',
   'In collaboration with the UNESCO regional office. Targeted more than 10,000 marginalized students in public schools, piloting extracurricular activities as a means to reinsert out-of-school children and retain students at risk of dropping out.', 1),
  ('Lebanese Palestinian Chamber Choir', '2009 – 2011',
   'In collaboration with UNDP. In the aftermath of the 2011 war at Nahr El Bared camp, it aimed to refoster peaceful relations between Palestinian residents of the camp and the Lebanese villages nearby.', 2),
  ('Sonbula Choir', '2014 – 2022',
   'In coordination with the Sonbula Association for Syrian Refugees in Lebanon, funded by Nai Association in Austria. Targeted 150 refugee children from camps across the Bekaa region.', 3),
  ('Angham w Salam Choir', '2022 – Present',
   'In coordination with UNDP, funded by KFW development bank. A nationwide community choir with 150 members and four branches across Lebanese provinces. Currently training 15 conductors; two choirs have already emerged — Maqam Choir and Fan Choir.', 4);

-- ============== TESTIMONIALS ==============
create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  author text not null,
  voice_section text,
  body text not null,
  status text not null default 'pending', -- pending | approved | rejected
  submitted_at timestamptz default now()
);
alter table public.testimonials enable row level security;
-- Audience can only see APPROVED testimonials
create policy "Approved testimonials are publicly readable"
  on public.testimonials for select
  using (status = 'approved');
-- Anyone can submit a testimonial (audience can also submit)
create policy "Anyone can submit a testimonial"
  on public.testimonials for insert
  with check (true);

insert into public.testimonials (author, voice_section, body, status) values
  ('Nour Khoury', 'Soprano',
   'Fayha has become my second family. Every rehearsal, every concert — I leave feeling lifted, no matter what kind of week I had. Singing in Arabic with this ensemble has reconnected me with a part of myself I didn''t know I had lost.',
   'approved'),
  ('Karim Saade', 'Bass 1',
   'Joining the choir was the best decision I made in 2023. The musical depth, the friendship, the discipline — it''s a craft that has shaped me beyond singing.',
   'approved'),
  ('Layla Hadad', 'Alto',
   'There is something sacred about the moment right before we start a piece. We breathe together, and the room becomes something else.',
   'pending');

-- ============== SOCIAL POSTS (Instagram/Facebook feed) ==============
create table if not exists public.social_posts (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  author text not null,
  body text not null,
  posted_label text not null,
  posted_at timestamptz default now()
);
alter table public.social_posts enable row level security;
create policy "Social posts are publicly readable" on public.social_posts for select using (true);

insert into public.social_posts (platform, author, body, posted_label, posted_at) values
  ('Instagram', '@fayhachoir',
   'Tonight in Tripoli — full house, full hearts. Thank you to everyone who came!',
   '2 days ago', now() - interval '2 days'),
  ('Facebook', 'Fayha National Choir',
   'Behind the scenes from the Angham w Salam rehearsal — 200 voices in one hall.',
   '5 days ago', now() - interval '5 days'),
  ('Instagram', '@fayhachoir',
   'Workshop with the European Choral Association: a week of exchange in the heart of Beirut.',
   '2 weeks ago', now() - interval '14 days');

-- ============== NEWSLETTER SUBSCRIPTIONS ==============
create table if not exists public.newsletter_subscriptions (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  subscribed_at timestamptz default now()
);
alter table public.newsletter_subscriptions enable row level security;
-- Anyone can subscribe
create policy "Anyone can subscribe to newsletter"
  on public.newsletter_subscriptions for insert
  with check (true);
-- Nobody public can read the list (only service_role / admins)
-- No SELECT policy = no public reads by default.
