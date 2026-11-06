"""Hourly PVPC electricity price from Red Eléctrica (REData API, no key needed).

Loads today and tomorrow (Madrid time) and upserts them into luz_horaria.
Tomorrow's prices exist from about 20:15; before that only today is stored.

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.luz
    python -m onda_workers.luz --dry-run
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Any

import psycopg
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from .ministerio import MADRID

log = logging.getLogger("onda_workers.luz")

API_URL = "https://apidatos.ree.es/es/datos/mercados/precios-mercados-tiempo-real"
PVPC = "PVPC"


class REEError(RuntimeError):
    """The API answered, but without usable PVPC data."""


@dataclass(frozen=True)
class HourPrice:
    hour: datetime          # timezone-aware start of the hour
    eur_mwh: Decimal


def parse_pvpc(payload: dict[str, Any]) -> list[HourPrice]:
    """REData response -> PVPC prices per hour, sorted."""
    series = next((s for s in payload.get("included", []) if s.get("type") == PVPC), None)
    if series is None:
        raise REEError("No PVPC series in the response")
    prices = []
    for v in series["attributes"]["values"]:
        value = v.get("value")
        if value is None or value < 0:
            continue
        prices.append(HourPrice(datetime.fromisoformat(v["datetime"]), Decimal(str(value)).quantize(Decimal("0.01"))))
    return sorted(prices, key=lambda p: p.hour)


def fetch_day(day: date) -> list[HourPrice]:
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=Retry(total=3, backoff_factor=3, status_forcelist=(429, 500, 502, 503, 504))))
    response = session.get(
        API_URL,
        params={"start_date": f"{day}T00:00", "end_date": f"{day}T23:59", "time_trunc": "hour"},
        headers={"User-Agent": "onda-workers/0.1", "Accept": "application/json"},
        timeout=30,
    )
    if response.status_code == 404 or (response.status_code == 502 and day > datetime.now(MADRID).date()):
        return []                                   # tomorrow not published yet
    response.raise_for_status()
    return parse_pvpc(response.json())


def store(conn: psycopg.Connection, prices: list[HourPrice]) -> int:
    with conn.transaction(), conn.cursor() as cur:
        cur.executemany(
            """
            insert into public.luz_horaria (hour, pvpc_eur_mwh) values (%s, %s)
            on conflict (hour) do update set pvpc_eur_mwh = excluded.pvpc_eur_mwh, updated_at = now()
            where luz_horaria.pvpc_eur_mwh is distinct from excluded.pvpc_eur_mwh
            """,
            [(p.hour, p.eur_mwh) for p in prices],
        )
        return cur.rowcount


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    today = datetime.now(MADRID).date()
    prices: list[HourPrice] = []
    for day in (today, today + timedelta(days=1)):
        try:
            day_prices = fetch_day(day)
        except (requests.RequestException, REEError) as e:
            if day == today:
                log.error("Today's prices failed: %s", e)
                return 1
            log.info("Tomorrow's prices not available yet (%s)", e)
            continue
        if day_prices:
            avg = sum(p.eur_mwh for p in day_prices) / len(day_prices)
            log.info("%s: %d hours, average %.2f €/MWh", day, len(day_prices), avg)
        prices.extend(day_prices)

    if args.dry_run:
        return 0
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set")
        return 2
    with psycopg.connect(database_url, prepare_threshold=None) as conn:
        log.info("Stored %d new or changed hours", store(conn, prices))
    return 0


if __name__ == "__main__":
    sys.exit(main())
