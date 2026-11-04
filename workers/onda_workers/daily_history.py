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
from concurrent.futures import FIRST_COMPLETED, Future, ThreadPoolExecutor, wait
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
# Parallel downloads: enough to hide the slow transfer from GitHub runners,
# few enough not to load the Ministry's servers.
DEFAULT_WORKERS = 3


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
    parser.add_argument("--max-minutes", type=float, default=None,
                        help="stop cleanly after this many minutes (GitHub jobs are cut at 6 h)")
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS,
                        help="parallel downloads")
    parser.add_argument("--dry-run", action="store_true",
                        help="download and aggregate, but do not touch the database")
    return parser.parse_args(argv)


def _download(day: date) -> tuple[list[DailyPrice], float]:
    started = time.monotonic()
    rows = aggregate(fetch_day(day), day)
    return rows, time.monotonic() - started


def run(
    days: list[date],
    conn: psycopg.Connection | None,
    workers: int = DEFAULT_WORKERS,
    max_minutes: float | None = None,
) -> int:
    """Load the given days; return how many were not loaded (failed or left for later).

    Downloads run in `workers` threads (each day is a ~12 MB response, and from
    a GitHub runner one download takes ~35 s). Storing happens in this thread
    only, since a psycopg connection must not be shared between threads.
    """
    deadline = time.monotonic() + max_minutes * 60 if max_minutes else None
    loaded = consecutive = 0
    pending_days = iter(days)
    in_flight: dict[Future, date] = {}

    with ThreadPoolExecutor(max_workers=workers) as pool:
        def submit_next() -> bool:
            """Queue the next day; False when there are no days left."""
            day = next(pending_days, None)
            if day is None:
                return False
            in_flight[pool.submit(_download, day)] = day
            return True

        # Keep at most `workers` downloads queued, so stopping (failures or
        # time budget) takes effect right away instead of after the whole list.
        for _ in range(workers):
            submit_next()

        stop = False
        while in_flight and not stop:
            done, _ = wait(in_flight, return_when=FIRST_COMPLETED)
            for future in done:
                day = in_flight.pop(future)
                try:
                    rows, seconds = future.result()
                except (requests.RequestException, MinisterioError, ValueError) as e:
                    consecutive += 1
                    log.warning("%s: failed (%s)", day, e)
                    if consecutive >= MAX_CONSECUTIVE_FAILURES:
                        log.error("%d failures in a row; stopping", consecutive)
                        stop = True
                    continue
                consecutive = 0
                stored = store_day(conn, rows) if conn else 0
                loaded += 1
                national = next(
                    (r for r in rows if (r.province_id, r.fuel) == (NATIONAL, "gasoleo_a")), None)
                log.info("[%d/%d] %s: %d rows stored%s, gasóleo A España %s €/l (download %.1f s)",
                         loaded, len(days), day, stored, "" if conn else " (dry run)",
                         national.avg_price if national else "?", seconds)
            if deadline and time.monotonic() > deadline:
                log.info("Time budget of %s min used up; the next run continues", max_minutes)
                stop = True
            while not stop and len(in_flight) < workers and submit_next():
                pass
        # Downloads still in flight when stopping are discarded (at most `workers`).
    return len(days) - loaded


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    args = _parse_args(argv)
    until = args.until or yesterday_in_madrid()
    if args.since > until:
        log.error("--since %s is after --until %s", args.since, until)
        return 2

    if args.dry_run:
        days = days_between(args.since, until)[: args.limit]
        return 1 if run(days, None, args.workers, args.max_minutes) else 0

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
        pending = run(todo, conn, args.workers, args.max_minutes)

    if pending:
        log.warning("%d days not loaded yet; the next run will retry them", pending)
    # Exit 1 only if nothing at all could be loaded: the Ministry is down or blocking us.
    return 1 if todo and pending == len(todo) else 0


if __name__ == "__main__":
    sys.exit(main())
