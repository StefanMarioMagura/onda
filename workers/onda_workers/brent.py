"""Daily Brent price (EIA) converted to euros with the ECB reference rate.

- Brent: EIA API v2, series RBRTE (Europe Brent Spot Price FOB, $/barrel).
  The EIA publishes weekly, so the latest value is usually 5-9 days old.
  Needs a free API key in EIA_API_KEY (sent in a header, never in the URL).
- EUR/USD: ECB Data Portal, series EXR.D.USD.EUR.SP00.A (USD per 1 EUR).
  No key needed.

Each run re-reads the last REFETCH_DAYS days (the EIA fills in late days and
sometimes revises values) and upserts them; the first run loads everything
since DEFAULT_SINCE.

Usage:
    EIA_API_KEY=... DATABASE_URL=postgresql://... python -m onda_workers.brent
    EIA_API_KEY=... python -m onda_workers.brent --dry-run --since 2025-12-01
"""

from __future__ import annotations

import argparse
import bisect
import csv
import io
import logging
import os
import sys
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation
from typing import Any

import psycopg
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

log = logging.getLogger("onda_workers.brent")

EIA_URL = "https://api.eia.gov/v2/petroleum/pri/spt/data/"
EIA_SERIES = "RBRTE"
EIA_PAGE = 5000  # the API's maximum rows per JSON response
ECB_URL = "https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A"

# The price history starts on 2019-01-01 and the model looks 14 days back.
DEFAULT_SINCE = date(2018, 12, 1)
REFETCH_DAYS = 30
# A Brent day whose latest ECB rate is older than this is skipped: the ECB
# never closes this long, so it would mean the rate download is incomplete.
MAX_FX_AGE_DAYS = 7


class SourceError(RuntimeError):
    """A source answered, but not with data we can use."""


@dataclass(frozen=True)
class BrentDay:
    day: date
    brent_usd: Decimal
    usd_per_eur: Decimal
    fx_day: date

    @property
    def brent_eur(self) -> Decimal:
        """Same formula as the generated column in brent_diario."""
        return (self.brent_usd / self.usd_per_eur).quantize(Decimal("0.001"))


# --------------------------------------------------------------------------
# Parsers (pure)
# --------------------------------------------------------------------------

def _decimal(raw: Any) -> Decimal | None:
    try:
        value = Decimal(str(raw).strip())
    except (InvalidOperation, ValueError):
        return None
    return value if value.is_finite() and value > 0 else None


def parse_eia(payload: dict[str, Any]) -> dict[date, Decimal]:
    """EIA v2 response -> {day: $/barrel}. Rows without a usable value are dropped."""
    if "error" in payload:
        raise SourceError(f"EIA error: {payload['error']}")
    try:
        rows = payload["response"]["data"]
    except (KeyError, TypeError) as e:
        raise SourceError("EIA response has no response.data") from e

    prices = {}
    for row in rows:
        if row.get("series") != EIA_SERIES:
            continue
        value = _decimal(row.get("value"))
        if value is None:
            log.warning("EIA %s: unusable value %r", row.get("period"), row.get("value"))
            continue
        prices[date.fromisoformat(row["period"])] = value
    return prices


def parse_ecb_csv(text: str) -> dict[date, Decimal]:
    """ECB 'csvdata' response -> {day: USD per EUR}."""
    reader = csv.DictReader(io.StringIO(text))
    if not reader.fieldnames or not {"TIME_PERIOD", "OBS_VALUE"} <= set(reader.fieldnames):
        raise SourceError(f"Unexpected ECB columns: {reader.fieldnames}")
    rates = {}
    for row in reader:
        value = _decimal(row["OBS_VALUE"])
        if value is not None:
            rates[date.fromisoformat(row["TIME_PERIOD"])] = value
    return rates


def combine(brent: dict[date, Decimal], rates: dict[date, Decimal]) -> list[BrentDay]:
    """Pair each Brent day with the latest ECB rate on or before it.

    Days with no rate in the previous MAX_FX_AGE_DAYS are skipped.
    """
    fx_days = sorted(rates)
    result = []
    for day in sorted(brent):
        i = bisect.bisect_right(fx_days, day)
        if i == 0 or (day - fx_days[i - 1]).days > MAX_FX_AGE_DAYS:
            log.warning("%s: no ECB rate in the previous %d days; skipped", day, MAX_FX_AGE_DAYS)
            continue
        fx_day = fx_days[i - 1]
        result.append(BrentDay(day, brent[day], rates[fx_day], fx_day))
    return result


# --------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------

def _session() -> requests.Session:
    retry = Retry(total=4, backoff_factor=5, status_forcelist=(429, 500, 502, 503, 504))
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=retry))
    session.headers["User-Agent"] = "onda-workers/0.1"
    return session


def fetch_brent(api_key: str, since: date, session: requests.Session | None = None) -> dict[date, Decimal]:
    session = session or _session()
    prices: dict[date, Decimal] = {}
    offset = 0
    while True:
        response = session.get(
            EIA_URL,
            params={
                "frequency": "daily",
                "data[0]": "value",
                "facets[series][]": EIA_SERIES,
                "start": since.isoformat(),
                "sort[0][column]": "period",
                "sort[0][direction]": "asc",
                "offset": offset,
                "length": EIA_PAGE,
            },
            headers={"X-Api-Key": api_key},
            timeout=60,
        )
        response.raise_for_status()
        payload = response.json()
        prices.update(parse_eia(payload))
        total = int(payload["response"]["total"])
        offset += EIA_PAGE
        if offset >= total:
            return prices


def fetch_rates(since: date, session: requests.Session | None = None) -> dict[date, Decimal]:
    session = session or _session()
    response = session.get(
        ECB_URL,
        # Start a bit earlier so the first Brent days have a previous rate.
        params={"format": "csvdata", "startPeriod": (since - timedelta(days=MAX_FX_AGE_DAYS)).isoformat()},
        timeout=60,
    )
    response.raise_for_status()
    return parse_ecb_csv(response.text)


# --------------------------------------------------------------------------
# Database
# --------------------------------------------------------------------------

def last_day(conn: psycopg.Connection) -> date | None:
    return conn.execute("select max(day) from public.brent_diario").fetchone()[0]


def store(conn: psycopg.Connection, rows: list[BrentDay]) -> int:
    """Upsert rows in one statement; returns how many were inserted or changed."""
    if not rows:
        return 0
    with conn.transaction(), conn.cursor() as cur:
        cur.execute(
            """
            insert into public.brent_diario as b (day, brent_usd, usd_per_eur, fx_day)
            select * from unnest(%s::date[], %s::numeric[], %s::numeric[], %s::date[])
            on conflict (day) do update set
              brent_usd = excluded.brent_usd,
              usd_per_eur = excluded.usd_per_eur,
              fx_day = excluded.fx_day,
              updated_at = now()
            where (b.brent_usd, b.usd_per_eur, b.fx_day)
                  is distinct from (excluded.brent_usd, excluded.usd_per_eur, excluded.fx_day)
            """,
            [
                [r.day for r in rows],
                [r.brent_usd for r in rows],
                [r.usd_per_eur for r in rows],
                [r.fx_day for r in rows],
            ],
        )
        return cur.rowcount


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--since", type=date.fromisoformat, default=None,
                        help=f"first day to (re)load (default: last stored day - {REFETCH_DAYS}, "
                             f"or {DEFAULT_SINCE} if the table is empty)")
    parser.add_argument("--dry-run", action="store_true", help="download only; do not touch the database")
    args = parser.parse_args(argv)

    api_key = os.environ.get("EIA_API_KEY")
    if not api_key:
        log.error("EIA_API_KEY is not set")
        return 2
    database_url = os.environ.get("DATABASE_URL")
    if not args.dry_run and not database_url:
        log.error("DATABASE_URL is not set")
        return 2

    conn = None if args.dry_run else psycopg.connect(
        database_url, prepare_threshold=None, autocommit=True)  # pooler: no prepared statements
    try:
        since = args.since
        if since is None:
            last = last_day(conn) if conn else None
            since = last - timedelta(days=REFETCH_DAYS) if last else DEFAULT_SINCE

        session = _session()
        rows = combine(fetch_brent(api_key, since, session), fetch_rates(since, session))
        if not rows:
            log.error("No Brent data since %s", since)
            return 1
        latest = rows[-1]
        log.info("%d days since %s; latest %s: %s $/bbl, %s $/€ → %s €/bbl",
                 len(rows), since, latest.day, latest.brent_usd, latest.usd_per_eur, latest.brent_eur)
        if conn:
            log.info("Stored %d new or changed days", store(conn, rows))
    finally:
        if conn:
            conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
