"""Writes a Ministry snapshot into Supabase Postgres in one transaction.

- Stations are upserted (only rows whose data changed are rewritten).
- Prices are appended only when they differ from the station's latest
  stored price for that fuel, so `precios` is a change log.
- The snapshot is recorded in `capturas`; a snapshot already recorded is
  skipped, which makes the job safe to re-run.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import psycopg

from .ministerio import Snapshot

log = logging.getLogger(__name__)

STATION_COLUMNS = (
    "id", "brand", "address", "postal_code", "locality", "municipality", "province",
    "municipality_id", "province_id", "region_id", "opening_hours", "road_side",
    "sale_type", "latitude", "longitude",
)

UPSERT_STATIONS = """
insert into public.gasolineras as g (
  id, brand, address, postal_code, locality, municipality, province,
  municipality_id, province_id, region_id, opening_hours, road_side, sale_type,
  location, first_seen_at, last_seen_at, updated_at
)
select
  id, brand, address, postal_code, locality, municipality, province,
  municipality_id, province_id, region_id, opening_hours, road_side, sale_type,
  extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326)::extensions.geography,
  %(ts)s, %(ts)s, now()
from tmp_stations
on conflict (id) do update set
  brand = excluded.brand,
  address = excluded.address,
  postal_code = excluded.postal_code,
  locality = excluded.locality,
  municipality = excluded.municipality,
  province = excluded.province,
  municipality_id = excluded.municipality_id,
  province_id = excluded.province_id,
  region_id = excluded.region_id,
  opening_hours = excluded.opening_hours,
  road_side = excluded.road_side,
  sale_type = excluded.sale_type,
  location = excluded.location,
  last_seen_at = excluded.last_seen_at,
  updated_at = case
    when (g.brand, g.address, g.postal_code, g.locality, g.municipality, g.province,
          g.municipality_id, g.province_id, g.region_id, g.opening_hours, g.road_side,
          g.sale_type, g.location::text)
         is distinct from
         (excluded.brand, excluded.address, excluded.postal_code, excluded.locality,
          excluded.municipality, excluded.province, excluded.municipality_id,
          excluded.province_id, excluded.region_id, excluded.opening_hours,
          excluded.road_side, excluded.sale_type, excluded.location::text)
    then now() else g.updated_at end
"""

INSERT_CHANGED_PRICES = """
insert into public.precios (station_id, fuel, price, observed_at)
select t.station_id, t.fuel, t.price, %(ts)s
from tmp_prices t
left join lateral (
  select p.price, p.observed_at
  from public.precios p
  where p.station_id = t.station_id and p.fuel = t.fuel
  order by p.observed_at desc
  limit 1
) last on true
where last.price is distinct from t.price
  and (last.observed_at is null or last.observed_at < %(ts)s)
"""


@dataclass(frozen=True)
class IngestResult:
    already_ingested: bool
    stations: int
    prices: int
    changed: int


def store_snapshot(conn: psycopg.Connection, snapshot: Snapshot) -> IngestResult:
    ts = snapshot.timestamp
    with conn.transaction(), conn.cursor() as cur:
        # Serialise concurrent runs (e.g. a manual run overlapping the cron).
        cur.execute("select pg_advisory_xact_lock(hashtext('onda.ingest_prices'))")

        cur.execute("select 1 from public.capturas where source_timestamp = %s", (ts,))
        if cur.fetchone():
            return IngestResult(True, len(snapshot.stations), len(snapshot.prices), 0)

        cur.execute(
            """
            create temp table tmp_stations (
              id integer, brand text, address text, postal_code text, locality text,
              municipality text, province text, municipality_id text, province_id text,
              region_id text, opening_hours text, road_side text, sale_type text,
              latitude double precision, longitude double precision
            ) on commit drop
            """
        )
        with cur.copy(f"copy tmp_stations ({', '.join(STATION_COLUMNS)}) from stdin") as copy:
            for s in snapshot.stations:
                copy.write_row(tuple(getattr(s, c) for c in STATION_COLUMNS))
        cur.execute(UPSERT_STATIONS, {"ts": ts})

        cur.execute(
            "create temp table tmp_prices (station_id integer, fuel text, price numeric(6,3))"
            " on commit drop"
        )
        with cur.copy("copy tmp_prices (station_id, fuel, price) from stdin") as copy:
            for p in snapshot.prices:
                copy.write_row((p.station_id, p.fuel, p.price))
        cur.execute(INSERT_CHANGED_PRICES, {"ts": ts})
        changed = cur.rowcount

        cur.execute(
            """
            insert into public.capturas (source_timestamp, station_count, price_count, changed_count)
            values (%s, %s, %s, %s)
            """,
            (ts, len(snapshot.stations), len(snapshot.prices), changed),
        )

    return IngestResult(False, len(snapshot.stations), len(snapshot.prices), changed)
