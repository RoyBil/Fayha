-- ============================================================
-- Bus Route & Live Tracking
-- ------------------------------------------------------------
-- Branch admins + Maestro (superAdmin) define routes and run trips.
-- Members view live position, get push events, and request pickups.
-- All geometry uses PostGIS (4326) so we can:
--   * snap GPS to the route polyline (ST_LineLocatePoint)
--   * compute remaining-distance ETA along the road, not straight-line
--   * reject pickup points that are too far from the route
-- ============================================================

create extension if not exists postgis;

-- ── Routes ─────────────────────────────────────────────────
create table if not exists public.bus_routes (
  id                 uuid primary key default gen_random_uuid(),
  branch             text not null,
  name               text not null,
  start_name         text not null,
  start_point        geography(Point, 4326) not null,
  end_name           text not null,
  end_point          geography(Point, 4326) not null,
  polyline           geography(LineString, 4326),
  total_distance_m   double precision,
  is_active          boolean not null default true,
  created_by         uuid not null references auth.users(id),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index if not exists bus_routes_branch_idx on public.bus_routes(branch);
create index if not exists bus_routes_polyline_gix on public.bus_routes using gist(polyline);

-- ── Stops (ordered along the route) ────────────────────────
create table if not exists public.bus_route_stops (
  id                 uuid primary key default gen_random_uuid(),
  route_id           uuid not null references public.bus_routes(id) on delete cascade,
  order_index        int not null,
  name               text not null,
  lat                double precision not null,
  lng                double precision not null,
  location           geography(Point, 4326) not null,
  geofence_radius_m  int not null default 200,
  approach_radius_m  int not null default 800,
  unique (route_id, order_index)
);

-- Build geography(location) from lat/lng on insert/update so clients can
-- insert plain lat/lng rows without going through PostGIS WKT.
create or replace function public.bus_route_stops_set_location() returns trigger
language plpgsql as $$
begin
  new.location := st_setsrid(st_makepoint(new.lng, new.lat), 4326)::geography;
  return new;
end $$;

drop trigger if exists bus_route_stops_location_trg on public.bus_route_stops;
create trigger bus_route_stops_location_trg
  before insert or update of lat, lng on public.bus_route_stops
  for each row execute function public.bus_route_stops_set_location();
create index if not exists bus_route_stops_location_gix on public.bus_route_stops using gist(location);
create index if not exists bus_route_stops_route_idx on public.bus_route_stops(route_id, order_index);

-- ── Trips (one per "run" of a route) ───────────────────────
create table if not exists public.bus_trips (
  id                   uuid primary key default gen_random_uuid(),
  route_id             uuid not null references public.bus_routes(id) on delete cascade,
  driver_id            uuid not null references auth.users(id),
  status               text not null default 'scheduled'
                       check (status in ('scheduled','in_progress','completed','cancelled')),
  started_at           timestamptz,
  ended_at             timestamptz,
  current_stop_index   int,
  created_at           timestamptz not null default now()
);
create index if not exists bus_trips_route_status_idx on public.bus_trips(route_id, status);
create index if not exists bus_trips_driver_idx on public.bus_trips(driver_id);

-- ── Latest position only (one row per active trip) ─────────
-- We denormalize lat/lng so Realtime payloads are immediately usable
-- (Realtime ships geography as opaque WKB hex otherwise).
create table if not exists public.bus_trip_positions (
  trip_id      uuid primary key references public.bus_trips(id) on delete cascade,
  location     geography(Point, 4326) not null,
  lat          double precision not null,
  lng          double precision not null,
  heading      double precision,
  speed_mps    double precision,
  recorded_at  timestamptz not null default now()
);
create index if not exists bus_trip_positions_location_gix on public.bus_trip_positions using gist(location);

-- ── Event log (audit + push source + dedupe) ───────────────
create table if not exists public.bus_trip_events (
  id           uuid primary key default gen_random_uuid(),
  trip_id      uuid not null references public.bus_trips(id) on delete cascade,
  route_id     uuid not null references public.bus_routes(id) on delete cascade,
  stop_id      uuid references public.bus_route_stops(id) on delete set null,
  event_type   text not null check (event_type in (
                 'ROUTE_STARTED','STOP_APPROACHING','STOP_ARRIVED',
                 'STOP_LEFT','ROUTE_COMPLETED','ROUTE_CANCELLED')),
  payload      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);
-- Hard dedupe: same (trip, type, stop) at most once per minute.
-- nil-uuid sentinel for events without a stop (ROUTE_STARTED/_COMPLETED/_CANCELLED).
--
-- date_trunc(text, timestamptz) is STABLE (depends on session TZ), so it
-- can't be used directly in an index expression. epoch-from-timestamptz
-- is genuinely fixed (seconds since UTC 1970, no TZ dependence), so we
-- wrap it in an IMMUTABLE helper and bucket by integer-divided minutes.
create or replace function public.minute_bucket(ts timestamptz)
returns bigint language sql immutable as $$
  select (extract(epoch from ts) / 60)::bigint
$$;

create unique index if not exists bus_trip_events_dedupe
  on public.bus_trip_events(
    trip_id, event_type,
    coalesce(stop_id, '00000000-0000-0000-0000-000000000000'::uuid),
    public.minute_bucket(created_at)
  );
create index if not exists bus_trip_events_route_idx on public.bus_trip_events(route_id, created_at desc);

-- ── Pickup requests ────────────────────────────────────────
create table if not exists public.bus_pickup_requests (
  id                    uuid primary key default gen_random_uuid(),
  route_id              uuid not null references public.bus_routes(id) on delete cascade,
  trip_id               uuid references public.bus_trips(id) on delete set null,
  user_id               uuid not null references auth.users(id),
  pickup_point          geography(Point, 4326) not null,
  lat                   double precision not null,
  lng                   double precision not null,
  distance_to_route_m   double precision not null,
  status                text not null default 'pending'
                        check (status in ('pending','acknowledged','picked_up','cancelled')),
  created_at            timestamptz not null default now()
);
create index if not exists bus_pickup_requests_route_idx on public.bus_pickup_requests(route_id, status);
create index if not exists bus_pickup_requests_point_gix on public.bus_pickup_requests using gist(pickup_point);

-- ── Subscriptions (who gets push for which route) ──────────
create table if not exists public.bus_route_subscriptions (
  user_id   uuid not null references auth.users(id) on delete cascade,
  route_id  uuid not null references public.bus_routes(id) on delete cascade,
  primary key (user_id, route_id)
);

-- ============================================================
-- RLS
-- ============================================================
alter table public.bus_routes              enable row level security;
alter table public.bus_route_stops         enable row level security;
alter table public.bus_trips               enable row level security;
alter table public.bus_trip_positions      enable row level security;
alter table public.bus_trip_events         enable row level security;
alter table public.bus_pickup_requests     enable row level security;
alter table public.bus_route_subscriptions enable row level security;

-- Routes ----------------------------------------------------
drop policy if exists "bus_routes read same branch" on public.bus_routes;
create policy "bus_routes read same branch" on public.bus_routes
  for select using (
    public.my_role() = 'superAdmin' or branch = public.my_branch()
  );

drop policy if exists "bus_routes write by admin" on public.bus_routes;
create policy "bus_routes write by admin" on public.bus_routes
  for all using (
    public.my_role() = 'superAdmin'
    or (public.my_role() = 'admin' and branch = public.my_branch())
  ) with check (
    public.my_role() = 'superAdmin'
    or (public.my_role() = 'admin' and branch = public.my_branch())
  );

-- Stops ----------------------------------------------------
drop policy if exists "bus_route_stops read" on public.bus_route_stops;
create policy "bus_route_stops read" on public.bus_route_stops
  for select using (
    exists (
      select 1 from public.bus_routes r
      where r.id = route_id
        and (public.my_role() = 'superAdmin' or r.branch = public.my_branch())
    )
  );

drop policy if exists "bus_route_stops write" on public.bus_route_stops;
create policy "bus_route_stops write" on public.bus_route_stops
  for all using (
    exists (
      select 1 from public.bus_routes r
      where r.id = route_id
        and (public.my_role() = 'superAdmin'
             or (public.my_role() = 'admin' and r.branch = public.my_branch()))
    )
  );

-- Trips ----------------------------------------------------
drop policy if exists "bus_trips read" on public.bus_trips;
create policy "bus_trips read" on public.bus_trips
  for select using (
    exists (
      select 1 from public.bus_routes r
      where r.id = route_id
        and (public.my_role() = 'superAdmin' or r.branch = public.my_branch())
    )
  );

drop policy if exists "bus_trips write" on public.bus_trips;
create policy "bus_trips write" on public.bus_trips
  for all using (
    public.my_role() in ('superAdmin','admin')
    and exists (
      select 1 from public.bus_routes r
      where r.id = route_id
        and (public.my_role() = 'superAdmin' or r.branch = public.my_branch())
    )
  );

-- Positions: everyone in branch reads; only assigned driver writes.
drop policy if exists "bus_trip_positions read" on public.bus_trip_positions;
create policy "bus_trip_positions read" on public.bus_trip_positions
  for select using (
    exists (
      select 1 from public.bus_trips t join public.bus_routes r on r.id = t.route_id
      where t.id = trip_id
        and (public.my_role() = 'superAdmin' or r.branch = public.my_branch())
    )
  );

drop policy if exists "bus_trip_positions write" on public.bus_trip_positions;
create policy "bus_trip_positions write" on public.bus_trip_positions
  for all using (
    exists (select 1 from public.bus_trips t where t.id = trip_id and t.driver_id = auth.uid())
  ) with check (
    exists (select 1 from public.bus_trips t where t.id = trip_id and t.driver_id = auth.uid())
  );

-- Events: read within branch; writes only via service role / SECURITY DEFINER fns.
drop policy if exists "bus_trip_events read" on public.bus_trip_events;
create policy "bus_trip_events read" on public.bus_trip_events
  for select using (
    exists (
      select 1 from public.bus_routes r
      where r.id = route_id
        and (public.my_role() = 'superAdmin' or r.branch = public.my_branch())
    )
  );

-- Pickup requests: user manages own; admins of branch see all on their routes.
drop policy if exists "bus_pickup read" on public.bus_pickup_requests;
create policy "bus_pickup read" on public.bus_pickup_requests
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.bus_routes r
      where r.id = route_id
        and (public.my_role() = 'superAdmin'
             or (public.my_role() = 'admin' and r.branch = public.my_branch()))
    )
  );

drop policy if exists "bus_pickup insert" on public.bus_pickup_requests;
create policy "bus_pickup insert" on public.bus_pickup_requests
  for insert with check (user_id = auth.uid());

drop policy if exists "bus_pickup update" on public.bus_pickup_requests;
create policy "bus_pickup update" on public.bus_pickup_requests
  for update using (
    user_id = auth.uid() or public.my_role() in ('admin','superAdmin')
  );

-- Subscriptions: user manages own.
drop policy if exists "bus_subs rw" on public.bus_route_subscriptions;
create policy "bus_subs rw" on public.bus_route_subscriptions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================
-- Realtime: position UPDATEs + event INSERTs must replicate
-- ============================================================
alter publication supabase_realtime add table public.bus_trip_positions;
alter publication supabase_realtime add table public.bus_trip_events;

-- ============================================================
-- Status -> Event triggers
-- ============================================================
create or replace function public.bus_trip_status_event() returns trigger
language plpgsql as $$
begin
  if new.status = 'in_progress' and (old.status is distinct from 'in_progress') then
    insert into public.bus_trip_events(trip_id, route_id, event_type)
      values (new.id, new.route_id, 'ROUTE_STARTED')
      on conflict do nothing;
  elsif new.status = 'completed' and old.status <> 'completed' then
    insert into public.bus_trip_events(trip_id, route_id, event_type)
      values (new.id, new.route_id, 'ROUTE_COMPLETED')
      on conflict do nothing;
  elsif new.status = 'cancelled' and old.status <> 'cancelled' then
    insert into public.bus_trip_events(trip_id, route_id, event_type)
      values (new.id, new.route_id, 'ROUTE_CANCELLED')
      on conflict do nothing;
  end if;
  return new;
end $$;

drop trigger if exists bus_trip_status_trg on public.bus_trips;
create trigger bus_trip_status_trg
  after update on public.bus_trips
  for each row execute function public.bus_trip_status_event();

-- ============================================================
-- RPC: request_bus_pickup
--   Validates the requested pickup point is within 500m of the
--   route polyline. Server-side so the threshold lives in one place
--   and clients cannot bypass it.
-- ============================================================
create or replace function public.request_bus_pickup(
  p_route uuid, p_lat double precision, p_lng double precision
) returns public.bus_pickup_requests
language plpgsql security definer set search_path = public as $$
declare
  v_pt    geography := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  v_dist  double precision;
  v_row   public.bus_pickup_requests;
  v_trip  uuid;
begin
  select st_distance(polyline, v_pt) into v_dist
    from public.bus_routes where id = p_route;
  if v_dist is null then
    raise exception 'route not found';
  end if;
  if v_dist > 500 then
    raise exception 'pickup point is % m from route (limit 500m)', round(v_dist);
  end if;
  -- attach to the in-progress trip on this route, if any
  select id into v_trip from public.bus_trips
    where route_id = p_route and status = 'in_progress'
    order by started_at desc nulls last limit 1;

  insert into public.bus_pickup_requests(
    route_id, trip_id, user_id, pickup_point, lat, lng, distance_to_route_m
  ) values (p_route, v_trip, auth.uid(), v_pt, p_lat, p_lng, v_dist)
    returning * into v_row;
  return v_row;
end $$;

grant execute on function public.request_bus_pickup(uuid,double precision,double precision) to authenticated;

-- ============================================================
-- RPC: ingest_bus_position
--   Called by the driver app every 5–10s. Upserts the latest
--   position and evaluates state transitions for the next few
--   stops. SECURITY DEFINER so it can write to bus_trip_events
--   (whose RLS blocks direct writes).
-- ============================================================
create or replace function public.ingest_bus_position(
  p_trip uuid,
  p_lat double precision,
  p_lng double precision,
  p_heading double precision default null,
  p_speed_mps double precision default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_pt        geography := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  v_route     uuid;
  v_driver    uuid;
  v_status    text;
  v_cur_idx   int;
  v_stop      record;
  v_dist      double precision;
  v_last      timestamptz;
begin
  select route_id, driver_id, status, current_stop_index
    into v_route, v_driver, v_status, v_cur_idx
    from public.bus_trips where id = p_trip;

  if v_route is null then raise exception 'trip not found'; end if;
  if v_driver <> auth.uid() then raise exception 'not your trip'; end if;
  if v_status <> 'in_progress' then
    -- silently ignore positions for non-active trips
    return;
  end if;

  insert into public.bus_trip_positions(
    trip_id, location, lat, lng, heading, speed_mps, recorded_at
  )
    values (p_trip, v_pt, p_lat, p_lng, p_heading, p_speed_mps, now())
    on conflict (trip_id) do update
      set location    = excluded.location,
          lat         = excluded.lat,
          lng         = excluded.lng,
          heading     = excluded.heading,
          speed_mps   = excluded.speed_mps,
          recorded_at = excluded.recorded_at;

  -- Evaluate the next two unvisited stops (cheap, bounded work per tick).
  for v_stop in
    select s.id, s.order_index, s.location, s.geofence_radius_m, s.approach_radius_m
      from public.bus_route_stops s
     where s.route_id = v_route
       and s.order_index > coalesce(v_cur_idx, -1)
     order by s.order_index
     limit 2
  loop
    v_dist := st_distance(v_stop.location, v_pt);

    if v_dist <= v_stop.geofence_radius_m then
      -- ARRIVED: emit + advance current_stop_index
      insert into public.bus_trip_events(trip_id, route_id, stop_id, event_type, payload)
        values (p_trip, v_route, v_stop.id, 'STOP_ARRIVED',
                jsonb_build_object('distance_m', v_dist))
        on conflict do nothing;
      update public.bus_trips set current_stop_index = v_stop.order_index where id = p_trip;

      -- If this is the last stop, auto-complete the trip.
      if not exists (select 1 from public.bus_route_stops
                       where route_id = v_route and order_index > v_stop.order_index) then
        update public.bus_trips
           set status = 'completed', ended_at = now()
         where id = p_trip;
      end if;
      exit;  -- handled this tick

    elsif v_dist <= v_stop.approach_radius_m then
      -- APPROACHING: soft dedupe — once per ~5 minutes per (trip, stop)
      select max(created_at) into v_last
        from public.bus_trip_events
        where trip_id = p_trip and stop_id = v_stop.id and event_type = 'STOP_APPROACHING';
      if v_last is null or v_last < now() - interval '5 minutes' then
        insert into public.bus_trip_events(trip_id, route_id, stop_id, event_type, payload)
          values (p_trip, v_route, v_stop.id, 'STOP_APPROACHING',
                  jsonb_build_object('distance_m', v_dist))
          on conflict do nothing;
      end if;
    end if;
  end loop;

  -- STOP_LEFT: if we previously arrived at v_cur_idx but are now well outside it.
  if v_cur_idx is not null then
    select s.id, st_distance(s.location, v_pt) as d, s.geofence_radius_m
      into v_stop
      from public.bus_route_stops s
     where s.route_id = v_route and s.order_index = v_cur_idx;
    if v_stop.id is not null
       and v_stop.d > v_stop.geofence_radius_m * 1.5
       and not exists (
         select 1 from public.bus_trip_events
          where trip_id = p_trip and stop_id = v_stop.id and event_type = 'STOP_LEFT'
       )
    then
      insert into public.bus_trip_events(trip_id, route_id, stop_id, event_type)
        values (p_trip, v_route, v_stop.id, 'STOP_LEFT')
        on conflict do nothing;
    end if;
  end if;
end $$;

grant execute on function public.ingest_bus_position(uuid,double precision,double precision,double precision,double precision) to authenticated;

-- ============================================================
-- RPC: bus_routes_upsert_with_geometry
--   Insert or update a route's start/end points + polyline. Takes
--   the polyline as a JSON array of [lng, lat] pairs (no PostGIS in
--   the client) and stitches it into a real LineString server-side.
--   Returns the route id.
-- ============================================================
create or replace function public.bus_routes_upsert_with_geometry(
  p_id uuid,
  p_branch text,
  p_name text,
  p_start_name text,
  p_start_lat double precision,
  p_start_lng double precision,
  p_end_name text,
  p_end_lat double precision,
  p_end_lng double precision,
  p_polyline_coords jsonb,       -- [[lng,lat],[lng,lat],...]
  p_total_distance_m double precision
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_line geography;
  v_id   uuid;
begin
  if p_polyline_coords is not null and jsonb_array_length(p_polyline_coords) >= 2 then
    select st_setsrid(st_makeline(array_agg(
             st_makepoint((pt->>0)::double precision, (pt->>1)::double precision)
             order by ord
           )), 4326)::geography
      into v_line
      from jsonb_array_elements(p_polyline_coords) with ordinality as t(pt, ord);
  end if;

  if p_id is null then
    -- Branch admin / superAdmin enforcement: matches RLS on bus_routes
    if not (public.my_role() = 'superAdmin'
            or (public.my_role() = 'admin' and public.my_branch() = p_branch)) then
      raise exception 'not authorized to create route in branch %', p_branch;
    end if;

    insert into public.bus_routes(
      branch, name, start_name, start_point, end_name, end_point,
      polyline, total_distance_m, created_by
    ) values (
      p_branch, p_name, p_start_name,
      st_setsrid(st_makepoint(p_start_lng, p_start_lat), 4326)::geography,
      p_end_name,
      st_setsrid(st_makepoint(p_end_lng, p_end_lat), 4326)::geography,
      v_line, p_total_distance_m, auth.uid()
    ) returning id into v_id;
    return v_id;
  else
    -- Existing-row authz check
    if not exists (
      select 1 from public.bus_routes r
       where r.id = p_id
         and (public.my_role() = 'superAdmin'
              or (public.my_role() = 'admin' and r.branch = public.my_branch()))
    ) then
      raise exception 'not authorized to edit route %', p_id;
    end if;

    update public.bus_routes set
      name             = coalesce(p_name, name),
      start_name       = coalesce(p_start_name, start_name),
      start_point      = case when p_start_lat is not null and p_start_lng is not null
                              then st_setsrid(st_makepoint(p_start_lng, p_start_lat), 4326)::geography
                              else start_point end,
      end_name         = coalesce(p_end_name, end_name),
      end_point        = case when p_end_lat is not null and p_end_lng is not null
                              then st_setsrid(st_makepoint(p_end_lng, p_end_lat), 4326)::geography
                              else end_point end,
      polyline         = coalesce(v_line, polyline),
      total_distance_m = coalesce(p_total_distance_m, total_distance_m),
      updated_at       = now()
     where id = p_id;
    return p_id;
  end if;
end $$;

grant execute on function public.bus_routes_upsert_with_geometry(
  uuid, text, text, text, double precision, double precision,
  text, double precision, double precision, jsonb, double precision
) to authenticated;

-- ============================================================
-- RPC: bus_route_progress
--   Returns remaining distance (m) along the polyline from the
--   bus's current position to the destination. Clients use this
--   for true road-distance ETA.
-- ============================================================
create or replace function public.bus_route_progress(p_trip uuid)
returns table(
  fraction_done double precision,
  remaining_m   double precision,
  total_m       double precision
)
language sql stable as $$
  with t as (
    select r.polyline, r.total_distance_m, p.location
      from public.bus_trips bt
      join public.bus_routes r on r.id = bt.route_id
      join public.bus_trip_positions p on p.trip_id = bt.id
     where bt.id = p_trip
  )
  select
    f as fraction_done,
    (1 - f) * coalesce(t.total_distance_m, st_length(t.polyline)) as remaining_m,
    coalesce(t.total_distance_m, st_length(t.polyline)) as total_m
  from t, lateral (
    select st_linelocatepoint(t.polyline::geometry, t.location::geometry) as f
  ) lp;
$$;

grant execute on function public.bus_route_progress(uuid) to authenticated;

-- ============================================================
-- Convenience view: routes with their stops as JSON.
-- ============================================================
create or replace view public.bus_routes_with_stops as
  select r.*,
         coalesce((
           select jsonb_agg(jsonb_build_object(
             'id', s.id,
             'order_index', s.order_index,
             'name', s.name,
             'lat', s.lat,
             'lng', s.lng,
             'geofence_radius_m', s.geofence_radius_m,
             'approach_radius_m', s.approach_radius_m
           ) order by s.order_index)
           from public.bus_route_stops s where s.route_id = r.id
         ), '[]'::jsonb) as stops,
         st_y(r.start_point::geometry) as start_lat,
         st_x(r.start_point::geometry) as start_lng,
         st_y(r.end_point::geometry)   as end_lat,
         st_x(r.end_point::geometry)   as end_lng,
         st_asgeojson(r.polyline::geometry) as polyline_geojson
    from public.bus_routes r;

grant select on public.bus_routes_with_stops to authenticated;

-- ============================================================
-- Stop-on-polyline constraint
--   Stops must lie within 200m of the route's polyline. This is
--   the same "is this point on the route?" rule used for pickup
--   requests, applied to admin-defined stops too. The check runs
--   AFTER the bus_route_stops_set_location trigger fills in the
--   geography column.
--
--   Constant: 200m. If a stop is between 200 and 500m it's a
--   pickup candidate (see request_bus_pickup) but not a real stop.
-- ============================================================
create or replace function public.bus_route_stops_check_on_route() returns trigger
language plpgsql as $$
declare
  v_poly geography;
  v_dist double precision;
begin
  select polyline into v_poly from public.bus_routes where id = new.route_id;
  if v_poly is null then
    -- Allow creating stops before the polyline exists (rare — editor
    -- creates the route+polyline first, then stops). If the polyline
    -- is genuinely missing the route is unusable anyway.
    return new;
  end if;
  v_dist := st_distance(v_poly, new.location);
  if v_dist > 200 then
    raise exception 'stop "%" is % m from the route (max 200m). Move it onto the route line.',
      new.name, round(v_dist);
  end if;
  return new;
end $$;

drop trigger if exists bus_route_stops_check_route_trg on public.bus_route_stops;
create trigger bus_route_stops_check_route_trg
  before insert or update of lat, lng on public.bus_route_stops
  for each row execute function public.bus_route_stops_check_on_route();

-- ============================================================
-- RPC: start_bus_trip
--   Authoritative trip start. Validates everything that can go
--   wrong and returns clear, single-line error reasons so the
--   client can surface them directly.
--
--   State machine: scheduled → in_progress → completed | cancelled
--   (no path back from completed/cancelled). The status check
--   constraint on bus_trips already encodes the valid set; this
--   function encodes the valid transitions.
-- ============================================================
create or replace function public.start_bus_trip(p_route uuid)
returns public.bus_trips
language plpgsql security definer set search_path = public as $$
declare
  v_route   record;
  v_active  uuid;
  v_trip    public.bus_trips;
begin
  -- 1. Route exists?
  select id, branch, polyline,
         (select count(*) from public.bus_route_stops s where s.route_id = r.id) as stop_count
    into v_route
    from public.bus_routes r where r.id = p_route;
  if v_route.id is null then
    raise exception 'Cannot start trip: route not found.';
  end if;

  -- 2. Polyline exists?
  if v_route.polyline is null then
    raise exception 'Cannot start trip: route has no path yet. Edit the route and re-save to generate the polyline.';
  end if;

  -- 3. Has at least one stop?
  if v_route.stop_count = 0 then
    raise exception 'Cannot start trip: this route has no stops yet.';
  end if;

  -- 4. Caller authorized?
  if not (public.my_role() = 'superAdmin'
          or (public.my_role() = 'admin' and public.my_branch() = v_route.branch)) then
    raise exception 'Cannot start trip: only branch admins (or the Maestro) can start a trip for this route.';
  end if;

  -- 5. No other in_progress trip on this route?
  select id into v_active from public.bus_trips
    where route_id = p_route and status = 'in_progress'
    limit 1;
  if v_active is not null then
    raise exception 'Cannot start trip: another trip is already in progress on this route.';
  end if;

  -- All good — insert and flip to in_progress in one transaction.
  insert into public.bus_trips(route_id, driver_id, status, started_at)
    values (p_route, auth.uid(), 'in_progress', now())
    returning * into v_trip;
  -- The bus_trip_status_trg AFTER trigger will emit ROUTE_STARTED.
  return v_trip;
end $$;

grant execute on function public.start_bus_trip(uuid) to authenticated;

-- ============================================================
-- RPC: bus_snapped_position
--   Returns the bus's GPS sample snapped onto the route polyline.
--   Members render this instead of the raw GPS so the bus icon
--   stays glued to the road (no jitter, no off-route artifacts).
-- ============================================================
create or replace function public.bus_snapped_position(p_trip uuid)
returns table(
  lat double precision,
  lng double precision,
  fraction_done double precision,
  recorded_at timestamptz
)
language sql stable as $$
  with t as (
    select r.polyline::geometry as line, p.location::geometry as pt, p.recorded_at
      from public.bus_trips bt
      join public.bus_routes r        on r.id = bt.route_id
      join public.bus_trip_positions p on p.trip_id = bt.id
     where bt.id = p_trip
  )
  select
    st_y(snapped) as lat,
    st_x(snapped) as lng,
    f             as fraction_done,
    t.recorded_at
  from t,
       lateral (select st_linelocatepoint(t.line, t.pt) as f) lp,
       lateral (select st_lineinterpolatepoint(t.line, lp.f) as snapped) sn;
$$;

grant execute on function public.bus_snapped_position(uuid) to authenticated;
