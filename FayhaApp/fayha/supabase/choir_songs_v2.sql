-- Voice section vocabulary update:
-- Old: Soprano 1, Soprano 2, Alto 1, Alto 2, Tenor 1, Tenor 2, Bass 1, Bass 2 (8 parts, all required)
-- New: Solo, Soprano, Mezzo Soprano, Alto, Contrary Alto, Tenor I, Tenor II, Baritone, Bass (9 parts, all optional)

-- 1) Drop NOT NULL on the old columns so they don't block new inserts.
alter table public.choir_songs alter column soprano1_url drop not null;
alter table public.choir_songs alter column soprano2_url drop not null;
alter table public.choir_songs alter column alto1_url    drop not null;
alter table public.choir_songs alter column alto2_url    drop not null;
alter table public.choir_songs alter column tenor1_url   drop not null;
alter table public.choir_songs alter column tenor2_url   drop not null;
alter table public.choir_songs alter column bass1_url    drop not null;
alter table public.choir_songs alter column bass2_url    drop not null;

-- 2) Add the 9 new columns (all nullable — admin uploads whichever parts they have).
alter table public.choir_songs
  add column if not exists solo_url          text,
  add column if not exists soprano_url       text,
  add column if not exists mezzo_soprano_url text,
  add column if not exists alto_url          text,
  add column if not exists contrary_alto_url text,
  add column if not exists tenor_i_url       text,
  add column if not exists tenor_ii_url      text,
  add column if not exists baritone_url      text,
  add column if not exists bass_url          text;

-- 3) Migrate existing data: roughly map old columns to nearest new column.
update public.choir_songs set
  soprano_url       = coalesce(soprano_url,       soprano1_url),
  mezzo_soprano_url = coalesce(mezzo_soprano_url, soprano2_url),
  alto_url          = coalesce(alto_url,          alto1_url),
  contrary_alto_url = coalesce(contrary_alto_url, alto2_url),
  tenor_i_url       = coalesce(tenor_i_url,       tenor1_url),
  tenor_ii_url      = coalesce(tenor_ii_url,      tenor2_url),
  baritone_url      = coalesce(baritone_url,      bass1_url),
  bass_url          = coalesce(bass_url,          bass2_url);

-- Old columns left in place for safety; remove later with:
--   alter table public.choir_songs drop column soprano1_url, drop column ...;
