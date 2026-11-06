"""Official INE statistics for "Tu España": food prices (CPI) and salaries.

Reads each series from the INE Tempus API (no key needed) and upserts it into
the indicadores table. INE revises recent values, so every run re-reads the
last periods and overwrites what changed.

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.ine
    python -m onda_workers.ine --dry-run
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Any

import psycopg
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from .ministerio import MADRID

log = logging.getLogger("onda_workers.ine")

API_URL = "https://servicios.ine.es/wstempus/js/ES/DATOS_SERIE/{code}"


@dataclass(frozen=True)
class Series:
    name: str        # ONDA name, stored in indicadores.serie
    code: str        # INE series code
    periods: int     # how many recent periods to read on each run


# Codes found through the Tempus API (TABLAS_OPERACION / DATOS_TABLA):
# - CPI table 76125 "Índices nacionales: general y de grupos ECOICOP ver.2"
# - Annual Wage Structure Survey (EAES) table 28191 "Medias y percentiles por sexo y CCAA"
SERIES = [
    Series("ipc_general_anual", "IPC290750", 25),     # CPI, overall, annual change (%)
    Series("ipc_alimentos_anual", "IPC290754", 25),   # CPI, food and non-alcoholic drinks, annual change (%)
    Series("salario_medio", "EAES741", 10),           # mean gross annual salary (€), both sexes, Spain
    Series("salario_mediana", "EAES738", 10),         # median gross annual salary (€)
]


class INEError(RuntimeError):
    """The API answered, but not with the expected series."""


@dataclass(frozen=True)
class Point:
    periodo: date
    valor: Decimal


def parse_series(payload: dict[str, Any], code: str) -> list[Point]:
    """Tempus DATOS_SERIE response -> points sorted by period.

    "Fecha" is the start of the period in ms since the epoch, at midnight
    Madrid time, so it is converted in Madrid to get the right day.
    Secret or missing values are skipped.
    """
    if payload.get("COD") != code:
        raise INEError(f"Expected series {code}, got {payload.get('COD')!r}")
    points = []
    for item in payload.get("Data", []):
        if item.get("Secreto") or item.get("Valor") is None:
            continue
        day = datetime.fromtimestamp(item["Fecha"] / 1000, MADRID).date()
        points.append(Point(day, Decimal(str(item["Valor"]))))
    return sorted(points, key=lambda p: p.periodo)


def fetch(series: Series, session: requests.Session) -> list[Point]:
    response = session.get(API_URL.format(code=series.code), params={"nult": series.periods}, timeout=60)
    response.raise_for_status()
    return parse_series(response.json(), series.code)


def store(conn: psycopg.Connection, series: Series, points: list[Point]) -> int:
    with conn.transaction(), conn.cursor() as cur:
        cur.executemany(
            """
            insert into public.indicadores (serie, periodo, valor, fuente) values (%s, %s, %s, %s)
            on conflict (serie, periodo) do update set
              valor = excluded.valor, fuente = excluded.fuente, updated_at = now()
            where indicadores.valor is distinct from excluded.valor
            """,
            [(series.name, p.periodo, p.valor, f"INE:{series.code}") for p in points],
        )
        return cur.rowcount


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=Retry(total=3, backoff_factor=3,
                                                            status_forcelist=(429, 500, 502, 503, 504))))
    session.headers["User-Agent"] = "onda-workers/0.1"

    loaded: dict[Series, list[Point]] = {}
    for series in SERIES:
        try:
            points = fetch(series, session)
        except (requests.RequestException, INEError, ValueError) as e:
            log.error("%s (%s) failed: %s", series.name, series.code, e)
            return 1
        if points:
            last = points[-1]
            log.info("%s: %d periods, latest %s = %s", series.name, len(points), last.periodo, last.valor)
        loaded[series] = points

    if args.dry_run:
        return 0
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set")
        return 2
    with psycopg.connect(database_url, prepare_threshold=None) as conn:
        changed = sum(store(conn, s, pts) for s, pts in loaded.items())
    log.info("Stored %d new or changed values", changed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
