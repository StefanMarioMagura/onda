"""Tests for the daily semáforo worker."""

from datetime import date, timedelta

import numpy as np
import pandas as pd
import pytest

from onda_workers.semaforo.daily import MODEL_VERSION, StaleDataError, forecast, store
from onda_workers.semaforo.data import load_series
from onda_workers.semaforo.features import classify

from .conftest import requires_db

LAST_DAY = date(2026, 11, 4)


def series(n=400, trend=0.001, seed=0):
    """Prices with a steady trend plus noise, ending on LAST_DAY; flat Brent."""
    rng = np.random.default_rng(seed)
    idx = pd.date_range(end=pd.Timestamp(LAST_DAY), periods=n, freq="D")
    prices = pd.Series(1.5 + np.arange(n) * trend + rng.normal(0, 0.002, n), index=idx)
    brent = pd.Series(80.0, index=idx[idx.day_of_week < 5])
    return prices, brent


def test_forecast_is_for_the_last_known_day():
    prices, brent = series()
    f = forecast(prices, brent, "gasoleo_a", today=LAST_DAY + timedelta(days=1))
    assert f.day == LAST_DAY
    assert f.price == pytest.approx(prices.iloc[-1])
    assert f.model == MODEL_VERSION
    # The last 7 days have no known outcome yet.
    assert f.trained_until == LAST_DAY - timedelta(days=7)


def test_rising_trend_gives_verde_and_signal_matches_expected_change():
    prices, brent = series(trend=0.002)          # +1.4 cent a week
    f = forecast(prices, brent, "gasoleo_a", today=LAST_DAY)
    assert f.expected_change > 0.01
    assert f.signal == "verde"
    assert f.signal == classify(f.expected_change)


def test_falling_trend_gives_rojo():
    prices, brent = series(trend=-0.002)
    assert forecast(prices, brent, "gasoleo_a", today=LAST_DAY).signal == "rojo"


def test_refuses_stale_data():
    prices, brent = series()
    with pytest.raises(StaleDataError):
        forecast(prices, brent, "gasoleo_a", today=LAST_DAY + timedelta(days=4))


def test_three_days_old_is_still_published():
    prices, brent = series()
    forecast(prices, brent, "gasoleo_a", today=LAST_DAY + timedelta(days=3))


def test_skips_trailing_days_without_features():
    prices, brent = series()
    prices = prices.drop(prices.index[-8])       # a gap makes price_7 unknown 7 days later
    f = forecast(prices, brent, "gasoleo_a", today=LAST_DAY)
    assert f.day == LAST_DAY - timedelta(days=1)


# --- database (integration) -------------------------------------------------

@requires_db
def test_store_upserts_one_row_per_day_and_fuel(conn):
    prices, brent = series()
    f = forecast(prices, brent, "gasoleo_a", today=LAST_DAY)
    store(conn, [f])
    store(conn, [f])                              # re-run the same day
    rows = conn.execute("select day, province_id, fuel, signal, model from public.semaforo_diario").fetchall()
    assert rows == [(LAST_DAY, "00", "gasoleo_a", f.signal, MODEL_VERSION)]


@requires_db
def test_load_series_reads_national_prices_and_brent(conn):
    conn.execute(
        """
        insert into public.precios_diarios values
          ('2026-11-03', '00', 'gasoleo_a', 1.5000, 1.499, 1.4, 1.6, 9000),
          ('2026-11-03', '02', 'gasoleo_a', 1.5100, 1.509, 1.4, 1.6, 200),
          ('2026-11-03', '00', 'gasoleo_premium', 1.6, 1.6, 1.5, 1.7, 5000)
        """
    )
    conn.execute("insert into public.brent_diario (day, brent_usd, usd_per_eur, fx_day)"
                 " values ('2026-11-02', 80, 1.1, '2026-11-02')")
    prices, brent = load_series(conn, ["gasoleo_a"])
    assert prices.to_dict("records") == [
        {"day": pd.Timestamp("2026-11-03"), "fuel": "gasoleo_a", "avg_price": 1.5}]
    assert brent.loc["2026-11-02"] == pytest.approx(80 / 1.1, abs=0.001)
