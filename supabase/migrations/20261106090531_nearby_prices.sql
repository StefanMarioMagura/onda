-- nearby_prices: like cheapest_stations, plus the average price and number of
-- all stations in the radius, so the app compares a station with what the user
-- would otherwise pay nearby. The national average is a different set of
-- stations: around central Madrid, for example, the area is pricier than it.
--
-- A new function rather than changing cheapest_stations: changing a return
-- type needs DROP FUNCTION. cheapest_stations is no longer used by the app and
-- can be dropped in a later cleanup migration.

create or replace function public.nearby_prices(
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
  observed_at timestamptz,
  area_avg_price numeric,
  area_station_count integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  with here as (
    select extensions.st_setsrid(extensions.st_makepoint(p_lon, p_lat), 4326)::extensions.geography as point
  ),
  nearby as (
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
  )
  select id, brand, address, locality, distance_km, price, observed_at,
         round(avg(price) over (), 3) as area_avg_price,
         (count(*) over ())::integer as area_station_count
  from nearby
  order by price, distance_km
  limit least(p_limit, 20);
$$;

revoke all on function public.nearby_prices(text, double precision, double precision, double precision, integer) from public;
grant execute on function public.nearby_prices(text, double precision, double precision, double precision, integer) to anon, authenticated;
