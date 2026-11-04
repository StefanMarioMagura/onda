"""Tests for the daily price history: aggregation (pure) and storage (needs a DB)."""

import json
from dataclasses import replace
from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest

from onda_workers.daily_history import (
    NATIONAL,
    aggregate,
    days_between,
    hist_url,
    loaded_days,
    store_day,
)
from onda_workers.ministerio import parse_snapshot, parse_timestamp

from .conftest import requires_db

FIXTURE = Path(__file__).parent / "fixtures" / "estaciones_sample.json"
DAY = date(2025, 11, 3)

# Fixture prices (€/l):
#   4375  Albacete (02): gasoleo_a 1.839, gasoleo_b 1.589, gasolina_95_e5 1.699
#   13639 Tenerife (38): gasoleo_a 1.609, gasolina_95_e5 1.459
#   14123 Albacete (02): glp 1.154, gasoleo_a 1.955, gasoleo_premium 2.035,
#                        gasolina_95_e5 1.759, gasolina_98_e5 1.904


@pytest.fixture
def snapshot():
    return parse_snapshot(json.loads(FIXTURE.read_text(encoding="utf-8")))


def by_key(rows):
    return {(r.province_id, r.fuel): r for r in rows}


# --- aggregate ------------------------------------------------------------

def test_aggregate_province_stats(snapshot):
    rows = by_key(aggregate(snapshot, DAY))
    albacete = rows[("02", "gasoleo_a")]
    assert albacete.day == DAY
    assert albacete.station_count == 2
    assert albacete.avg_price == Decimal("1.8970")
    assert albacete.min_price == Decimal("1.839")
    assert albacete.max_price == Decimal("1.955")
    # Even count: median_low keeps an observed price instead of averaging.
    assert albacete.median_price == Decimal("1.839")


def test_aggregate_national_row_covers_all_provinces(snapshot):
    national = by_key(aggregate(snapshot, DAY))[(NATIONAL, "gasoleo_a")]
    assert national.station_count == 3
    assert national.avg_price == Decimal("1.8010")   # (1.839 + 1.609 + 1.955) / 3
    assert national.median_price == Decimal("1.839")
    assert (national.min_price, national.max_price) == (Decimal("1.609"), Decimal("1.955"))


def test_aggregate_keeps_only_main_fuels(snapshot):
    fuels = {r.fuel for r in aggregate(snapshot, DAY)}
    assert fuels == {"gasoleo_a", "gasolina_95_e5", "gasoleo_premium", "gasolina_98_e5"}


def test_aggregate_skips_province_fuel_pairs_without_prices(snapshot):
    keys = set(by_key(aggregate(snapshot, DAY)))
    assert ("38", "gasolina_98_e5") not in keys
    assert len(keys) == 2 + 4 + 4   # Tenerife: 2 fuels, Albacete: 4, national: 4


def test_aggregate_skips_stations_without_province(snapshot):
    stations = [replace(s, province_id=None) if s.id == 13639 else s for s in snapshot.stations]
    rows = by_key(aggregate(replace(snapshot, stations=stations), DAY))
    assert not any(prov == "38" for prov, _ in rows)
    assert rows[(NATIONAL, "gasoleo_a")].station_count == 2


def test_aggregate_custom_fuels(snapshot):
    rows = aggregate(snapshot, DAY, fuels=("glp",))
    assert {(r.province_id, r.fuel) for r in rows} == {("02", "glp"), (NATIONAL, "glp")}


# --- helpers --------------------------------------------------------------

def test_days_between_is_inclusive_and_newest_first():
    assert days_between(date(2024, 2, 28), date(2024, 3, 1)) == [
        date(2024, 3, 1), date(2024, 2, 29), date(2024, 2, 28),
    ]
    assert days_between(DAY, DAY) == [DAY]


def test_hist_url_uses_spanish_date_format():
    assert hist_url(date(2025, 11, 3)).endswith("/EstacionesTerrestresHist/03-11-2025")


def test_parse_timestamp_accepts_historical_midnight():
    # The historical endpoint returns "Fecha" as midnight with a 1-digit hour.
    ts = parse_timestamp("03/11/2025 0:00:00")
    assert ts.date() == DAY
    assert ts.utcoffset().total_seconds() == 3600


# --- storage (integration) ------------------------------------------------

@requires_db
def test_store_day_and_loaded_days(conn, snapshot):
    rows = aggregate(snapshot, DAY)
    assert store_day(conn, rows) == len(rows)
    assert loaded_days(conn, date(2025, 11, 1), date(2025, 11, 30)) == {DAY}
    assert loaded_days(conn, date(2025, 12, 1), date(2025, 12, 31)) == set()


@requires_db
def test_store_day_is_idempotent(conn, snapshot):
    rows = aggregate(snapshot, DAY)
    store_day(conn, rows)
    assert store_day(conn, rows) == 0
    count = conn.execute("select count(*) from public.precios_diarios").fetchone()[0]
    assert count == len(rows)


@requires_db
def test_store_day_round_trips_values(conn, snapshot):
    store_day(conn, aggregate(snapshot, DAY))
    row = conn.execute(
        "select avg_price, median_price, min_price, max_price, station_count"
        " from public.precios_diarios where day = %s and province_id = '00' and fuel = 'gasoleo_a'",
        (DAY,),
    ).fetchone()
    assert row == (Decimal("1.8010"), Decimal("1.839"), Decimal("1.609"), Decimal("1.955"), 3)


@requires_db
def test_store_day_does_not_touch_live_tables(conn, snapshot):
    store_day(conn, aggregate(snapshot, DAY))
    assert conn.execute("select count(*) from public.precios").fetchone()[0] == 0



# --- run (orchestration, downloads simulated) ------------------------------

def test_run_counts_failed_days_and_keeps_going(monkeypatch, snapshot):
    from onda_workers import daily_history
    from onda_workers.ministerio import MinisterioError

    bad = {date(2025, 11, 2)}

    def fake_fetch(day):
        if day in bad:
            raise MinisterioError("broken day")
        return replace(snapshot, timestamp=snapshot.timestamp.replace(year=day.year, month=day.month, day=day.day))

    monkeypatch.setattr(daily_history, "fetch_day", fake_fetch)
    days = days_between(date(2025, 11, 1), date(2025, 11, 4))
    assert daily_history.run(days, None, workers=2) == 1


def test_run_stops_after_consecutive_failures(monkeypatch):
    from onda_workers import daily_history
    from onda_workers.ministerio import MinisterioError

    calls = []

    def always_fails(day):
        calls.append(day)
        raise MinisterioError("down")

    monkeypatch.setattr(daily_history, "fetch_day", always_fails)
    days = days_between(date(2025, 1, 1), date(2025, 12, 31))
    assert daily_history.run(days, None, workers=1) == len(days)   # nothing loaded
    assert len(calls) < 10                                          # gave up early
