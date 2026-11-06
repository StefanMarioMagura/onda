"""Daily semáforo: train the current model on all history and store today's forecast.

For each fuel, the forecast is made from the last day with known prices
(precios_diarios arrives the morning after) and saved in semaforo_diario.
Refuses to publish if that day is too old: a stale semáforo would mislead.

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.semaforo.daily
"""

from __future__ import annotations

import logging
import os
import sys
from dataclasses import dataclass
from datetime import date, datetime

import pandas as pd
import psycopg

from ..ministerio import MADRID
from .data import FUELS, load_series
from .features import BRENT_LAG_DAYS, build_dataset, classify
from .model import CURRENT, SemaforoModel, Variant, usable

log = logging.getLogger("onda_workers.semaforo.daily")

MODEL_VERSION = "v2"
# Daily prices normally lag one day; allow a couple more for a missed run.
MAX_STALENESS_DAYS = 3


class StaleDataError(RuntimeError):
    """The latest usable price day is too old to publish a forecast."""


@dataclass(frozen=True)
class Forecast:
    day: date
    fuel: str
    price: float
    expected_change: float
    signal: str
    price_7: float
    margin_gap: float
    trained_until: date
    model: str = MODEL_VERSION


def forecast(series: pd.Series, brent: pd.Series, fuel: str, today: date,
             variant: Variant = CURRENT) -> Forecast:
    """Forecast for the last day of `series` with every feature known."""
    data = build_dataset(series, brent, brent_lag_days=BRENT_LAG_DAYS)
    rows = usable(data, variant)
    if rows.empty:
        raise ValueError(f"No usable rows for {fuel}")
    last = rows.iloc[-1]
    day = rows.index[-1].date()
    if (today - day).days > MAX_STALENESS_DAYS:
        raise StaleDataError(f"{fuel}: latest usable day is {day}, more than {MAX_STALENESS_DAYS} days old")

    model = SemaforoModel.fit(data, variant)   # only rows whose 7-day outcome is known
    expected = float(model.predict(rows.iloc[[-1]]).iloc[0])
    trained_until = rows.dropna(subset=["change_7d"]).index[-1].date()
    return Forecast(
        day=day,
        fuel=fuel,
        price=float(last["price"]),
        expected_change=expected,
        signal=classify(expected),
        price_7=float(last["price_7"]),
        margin_gap=float(last["margin_gap"]),
        trained_until=trained_until,
    )


def store(conn: psycopg.Connection, forecasts: list[Forecast]) -> None:
    """Upsert: re-running on the same day replaces that day's forecast."""
    with conn.transaction(), conn.cursor() as cur:
        cur.executemany(
            """
            insert into public.semaforo_diario
              (day, province_id, fuel, model, price, expected_change, signal,
               price_7, margin_gap, trained_until)
            values (%s, '00', %s, %s, %s, %s, %s, %s, %s, %s)
            on conflict (day, province_id, fuel) do update set
              model = excluded.model, price = excluded.price,
              expected_change = excluded.expected_change, signal = excluded.signal,
              price_7 = excluded.price_7, margin_gap = excluded.margin_gap,
              trained_until = excluded.trained_until, created_at = now()
            """,
            [(f.day, f.fuel, f.model, round(f.price, 3), round(f.expected_change, 4), f.signal,
              round(f.price_7, 4), round(f.margin_gap, 4), f.trained_until) for f in forecasts],
        )


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set")
        return 2

    today = datetime.now(MADRID).date()
    with psycopg.connect(database_url, prepare_threshold=None) as conn:
        prices, brent = load_series(conn, list(FUELS))
        forecasts = []
        for fuel in FUELS:
            series = prices[prices["fuel"] == fuel].set_index("day")["avg_price"]
            try:
                f = forecast(series, brent, fuel, today)
            except StaleDataError as e:
                log.error("Not publishing: %s", e)
                return 1
            log.info("%s %s: %.3f €/l, expected %+.1f cent in 7 days -> %s",
                     f.day, fuel, f.price, f.expected_change * 100, f.signal)
            forecasts.append(f)
        store(conn, forecasts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
