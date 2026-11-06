-- Cheapest stations near a point, for "Tu bolsillo". Called by the app via RPC.
--
-- Uses the latest known price of each station (precios is a change log, so the
-- newest row is the current price). Only stations still listed by the Ministry
-- in the last 3 days and open to the public (sale_type 'P').
-- security invoker: runs with the caller's rights, so the read-only RLS
-- policies on gasolineras and precios still apply.
-- The app sends an approximate point (rounded to ~1 km, GDPR).

create or replace function public.cheapest_stations(
  p_fuel text,
  p_lat double precision,
  p_lon double precision,
  p_radius_km double precision default 10,
  p_limit integer default 5
)
returns table (
  station_id integer,
  brand text,
  address text,
  locality text,
  distance_km double precision,
  price numeric,
  observed_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  with here as (
    select extensions.st_setsrid(extensions.st_makepoint(p_lon, p_lat), 4326)::extensions.geography as point
  )
  select g.id, g.brand, g.address, g.locality,
         extensions.st_distance(g.location, here.point) / 1000 as distance_km,
         latest.price, latest.observed_at
  from public.gasolineras g
  cross join here
  cross join lateral (
    select p.price, p.observed_at
    from public.precios p
    where p.station_id = g.id and p.fuel = p_fuel
    order by p.observed_at desc
    limit 1
  ) latest
  -- Radius capped at 50 km and results at 20 to keep the query cheap.
  where extensions.st_dwithin(g.location, here.point, least(p_radius_km, 50) * 1000)
    and g.last_seen_at > now() - interval '3 days'
    and g.sale_type = 'P'
  order by latest.price, distance_km
  limit least(p_limit, 20);
$$;

revoke all on function public.cheapest_stations(text, double precision, double precision, double precision, integer) from public;
grant execute on function public.cheapest_stations(text, double precision, double precision, double precision, integer) to anon, authenticated;
