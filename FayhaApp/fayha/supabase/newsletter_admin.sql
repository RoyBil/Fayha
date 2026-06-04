-- Lets editors + super admins see who subscribed to the newsletter
-- and remove an entry if needed. Audience signups stay open to anyone.

-- Re-assert the public insert policy (some projects had the original
-- policy missing or replaced). The `to anon, authenticated` clause is
-- explicit so the audience (anon) web app can always sign up.
drop policy if exists "Anyone can subscribe to newsletter" on public.newsletter_subscriptions;
create policy "Anyone can subscribe to newsletter" on public.newsletter_subscriptions
  for insert to anon, authenticated
  with check (true);

-- Allow the `upsert(onConflict: 'email')` path the client uses: when
-- the email already exists, Postgres needs UPDATE privilege to do
-- the ON CONFLICT branch. Without this, every repeat signup fails.
drop policy if exists "Anyone can refresh subscription" on public.newsletter_subscriptions;
create policy "Anyone can refresh subscription" on public.newsletter_subscriptions
  for update to anon, authenticated
  using (true)
  with check (true);

drop policy if exists "Editors read newsletter" on public.newsletter_subscriptions;
create policy "Editors read newsletter" on public.newsletter_subscriptions
  for select to authenticated
  using (public.my_role() in ('editor', 'superAdmin'));

drop policy if exists "Editors delete newsletter" on public.newsletter_subscriptions;
create policy "Editors delete newsletter" on public.newsletter_subscriptions
  for delete to authenticated
  using (public.my_role() in ('editor', 'superAdmin'));
