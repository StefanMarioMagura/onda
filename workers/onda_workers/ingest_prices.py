"""Entry point: download the Ministry snapshot and store it.

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.ingest_prices
"""

from __future__ import annotations

import logging
import os
import sys

import psycopg

from .db import store_snapshot
from .ministerio import fetch_snapshot

log = logging.getLogger("onda_workers.ingest_prices")

# Safety net: if a snapshot suddenly has far fewer stations, something is
# wrong upstream and we'd rather fail loudly than record a broken snapshot.
MIN_STATIONS = 8000


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set")
        return 2

    snapshot = fetch_snapshot()
    log.info(
        "Snapshot %s: %d stations, %d prices, %d skipped",
        snapshot.timestamp.isoformat(), len(snapshot.stations),
        len(snapshot.prices), snapshot.skipped_stations,
    )
    if len(snapshot.stations) < MIN_STATIONS:
        log.error("Only %d stations (< %d); refusing to store", len(snapshot.stations), MIN_STATIONS)
        return 1

    # prepare_threshold=None: the Supabase pooler doesn't support prepared statements.
    with psycopg.connect(database_url, prepare_threshold=None) as conn:
        result = store_snapshot(conn, snapshot)

    if result.already_ingested:
        log.info("Snapshot already stored; nothing to do")
    else:
        log.info("Stored snapshot: %d price changes", result.changed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
