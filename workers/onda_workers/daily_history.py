"""Backfill and keep up to date the daily price statistics per province.

Source: the Ministry's historical endpoint, which returns the full station list
with the prices that applied on a given day (same format as the live API).
Each day is reduced to one row per (province, fuel) plus a national row
(province_id '00') and stored in `precios_diarios`.

The job fills every missing day between --since and yesterday, newest first,
so it is safe to re-run and a missed run is caught up by the next one.

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.daily_history [--since 2019-01-01]
    python -m onda_workers.daily_history --dry-run --since 2025-11-03 --until 2025-11-03
"""

from __future__ import annotations

import argparse
import logging
import os
import statistics
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal

import psycopg
import requests

from .ministerio import MADRID, MinisterioError, Snapshot, fetch_snapshot

log = logging.getLogger("onda_workers.daily_history")

HIST_URL = (
    "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/"
    "PreciosCarburantes/EstacionesTerrestresHist/"
)
NATIONAL = "00"
# Fuels kept in the daily history. The rest are too sparse to be useful and
# would multiply the table size.
MAIN_FUELS = ("gasoleo_a", "gasolina_95_e5", "gasoleo_premium", "gasolina_98_e5")
DEFAULT_SINCE = date(2019, 1, 1)
# Older years have fewer stations than today (~11,400), so the floor is
# lower than the live job's.
MIN_STATIONS = 5000
# Stop if the Ministry keeps failing: it is down or blocking us.
MAX_CONSECUTIVE_FAILURES = 5
PAUSE_SECONDS = 1.0


@dataclass(frozen=True)
class DailyPrice:
    day: date
    province_id: str
    fuel: str
    avg_price: Decimal
    median_price: Decimal
    min_price: Decimal
    max_price: Decimal
    station_count: int


# --------------------------------------------------------------------------
# Pure logic
# --------------------------------------------------------------------------

def hist_url(day: date) -> str:
    return HIST_URL + day.strftime("%d-%m-%Y")


def _stats(day: date, province_id: str, fuel: str, prices: list[Decimal]) -> DailyPrice:
    return DailyPrice(
        day=day,
        province_id=province_id,
        fuel=fuel,
        avg_price=(sum(prices) / len(prices)).quantize(Decimal("0.0001")),
        # median_low keeps a real observed price (3 decimals) for even counts.
        median_price=statistics.median_low(prices),
        min_price=min(prices),
        max_price=max(prices),
        station_count=len(prices),
    )


def aggregate(snapshot: Snapshot, day: date, fuels: tuple[str, ...] = MAIN_FUELS) -> list[DailyPrice]:
    """One row per (province, fuel) with at least one price, plus national rows."""
    province_of = {s.id: s.province_id for s in snapshot.stations}
    groups: dict[tuple[str, str], list[Decimal]] = defaultdict(list)
    for p in snapshot.prices:
        province = province_of.get(p.station_id)
        if p.fuel not in fuels or province is None:
            continue
        groups[(province, p.fuel)].append(p.price)
        groups[(NATIONAL, p.fuel)].append(p.price)
    return [_stats(day, prov, fuel, prices) for (prov, fuel), prices in sorted(groups.items())]


def days_between(since: date, until: date) -> list[date]:
    """Every day in [since, until], newest first."""
    return [until - timedelta(days=i) for i in range((until - since).days + 1)]


def yesterday_in_madrid() -> date:
    return datetime.now(MADRID).date() - timedelta(days=1)


# --------------------------------------------------------------------------
# Ministry + database
# --------------------------------------------------------------------------

def fetch_day(day: date) -> Snapshot:
    snapshot = fetch_snapshot(hist_url(day))
    if snapshot.timestamp.date() != day:
        raise MinisterioError(f"Asked for {day}, got data for {snapshot.timestamp.date()}")
    if len(snapshot.stations) < MIN_STATIONS:
        raise MinisterioError(f"Only {len(snapshot.stations)} stations for {day}")
    return snapshot


def loaded_days(conn: psycopg.Connection, since: date, until: date) -> set[date]:
    rows = conn.execute(
        "select distinct day from public.precios_diarios where day between %s and %s",
        (since, until),
    ).fetchall()
    return {r[0] for r in rows}


def store_day(conn: psycopg.Connection, rows: list[DailyPrice]) -> int:
    """Insert one day's rows atomically. Rows already stored are left untouched.

    All rows go in a single statement (one array per column) instead of one
    INSERT per row: from a GitHub runner each round trip to Supabase costs
    ~100 ms, which made 211 separate inserts the slowest part of the job.
    """
    columns = list(zip(*(
        (r.day, r.province_id, r.fuel, r.avg_price, r.median_price,
         r.min_price, r.max_price, r.station_count)
        for r in rows
    ))) or [[]] * 8
    with conn.transaction(), conn.cursor() as cur:
        cur.execute(
            """
            insert into public.precios_diarios
              (day, province_id, fuel, avg_price, median_price, min_price, max_price, station_count)
            select * from unnest(
              %s::date[], %s::text[], %s::text[], %s::numeric[],
              %s::numeric[], %s::numeric[], %s::numeric[], %s::integer[]
            )
            on conflict do nothing
            """,
            [list(c) for c in columns],
        )
        return cur.rowcount


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------

def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--since", type=date.fromisoformat, default=DEFAULT_SINCE)
    parser.add_argument("--until", type=date.fromisoformat, default=None,
                        help="last day to load (default: yesterday, Madrid time)")
    parser.add_argument("--limit", type=int, default=None,
                        help="load at most N missing days (to split a long backfill into runs)")
    parser.add_argument("--dry-run", action="store_true",
                        help="download and aggregate, but do not touch the database")
    return parser.parse_args(argv)


def run(days: list[date], conn: psycopg.Connection | None) -> int:
    """Load each day; return the number of days that failed."""
    failed = consecutive = 0
    for i, day in enumerate(days, 1):
        started = time.monotonic()
        try:
            rows = aggregate(fetch_day(day), day)
        except (requests.RequestException, MinisterioError, ValueError) as e:
            failed += 1
            consecutive += 1
            log.warning("%s: failed (%s)", day, e)
            if consecutive >= MAX_CONSECUTIVE_FAILURES:
                log.error("%d failures in a row; stopping", consecutive)
                return failed + len(days) - i
            continue
        consecutive = 0
        fetched = time.monotonic()
        national = next((r for r in rows if (r.province_id, r.fuel) == (NATIONAL, "gasoleo_a")), None)
        stored = store_day(conn, rows) if conn else 0
        log.info("[%d/%d] %s: %d rows stored%s, gasóleo A España %s €/l (download %.1f s, db %.1f s)",
                 i, len(days), day, stored, "" if conn else " (dry run)",
                 national.avg_price if national else "?",
                 fetched - started, time.monotonic() - fetched)
        time.sleep(PAUSE_SECONDS)
    return failed


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    args = _parse_args(argv)
    until = args.until or yesterday_in_madrid()
    if args.since > until:
        log.error("--since %s is after --until %s", args.since, until)
        return 2

    if args.dry_run:
        return 1 if run(days_between(args.since, until), None) else 0

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set")
        return 2

    # prepare_threshold=None: the Supabase pooler doesn't support prepared statements.
    # autocommit: each day commits on its own (store_day opens its transaction),
    # so a long backfill keeps its progress if it stops halfway.
    with psycopg.connect(database_url, prepare_threshold=None, autocommit=True) as conn:
        done = loaded_days(conn, args.since, until)
        todo = [d for d in days_between(args.since, until) if d not in done]
        log.info("%d days already loaded, %d missing", len(done), len(todo))
        if args.limit is not None:
            todo = todo[: args.limit]
        failed = run(todo, conn)

    if failed:
        log.error("%d days failed; re-run to retry them", failed)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
