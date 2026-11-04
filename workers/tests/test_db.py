"""Integration tests for store_snapshot against a real Postgres + PostGIS.

Skipped unless TEST_DATABASE_URL is set; see conftest.py.
"""

from dataclasses import replace
from datetime import timedelta
from decimal import Decimal
from pathlib import Path

import pytest

from onda_workers.db import store_snapshot
from onda_workers.ministerio import Price, parse_snapshot

from .conftest import requires_db

pytestmark = requires_db

FIXTURE = Path(__file__).parent / "fixtures" / "estaciones_sample.json"


@pytest.fixture
def snapshot():
    import json
    return parse_snapshot(json.loads(FIXTURE.read_text(encoding="utf-8")))


def count(conn, table):
    return conn.execute(f"select count(*) from public.{table}").fetchone()[0]


def test_first_snapshot_stores_everything(conn, snapshot):
    result = store_snapshot(conn, snapshot)
    assert not result.already_ingested
    assert result.changed == len(snapshot.prices)
    assert count(conn, "gasolineras") == 3
    assert count(conn, "precios") == len(snapshot.prices)
    lat, lon = conn.execute(
        "select extensions.st_y(location::extensions.geometry), extensions.st_x(location::extensions.geometry)"
        " from public.gasolineras where id = 4375"
    ).fetchone()
    assert (lat, lon) == pytest.approx((39.211417, -1.539167))


def test_same_snapshot_twice_is_idempotent(conn, snapshot):
    store_snapshot(conn, snapshot)
    result = store_snapshot(conn, snapshot)
    assert result.already_ingested
    assert count(conn, "precios") == len(snapshot.prices)
    assert count(conn, "capturas") == 1


def test_only_changed_prices_are_appended(conn, snapshot):
    store_snapshot(conn, snapshot)

    later = snapshot.timestamp + timedelta(minutes=30)
    changed = [
        replace(p, price=Decimal("1.799")) if (p.station_id, p.fuel) == (4375, "gasoleo_a") else p
        for p in snapshot.prices
    ]
    result = store_snapshot(conn, replace(snapshot, timestamp=later, prices=changed))

    assert result.changed == 1
    assert count(conn, "precios") == len(snapshot.prices) + 1
    history = conn.execute(
        "select price from public.precios where station_id = 4375 and fuel = 'gasoleo_a'"
        " order by observed_at"
    ).fetchall()
    assert [h[0] for h in history] == [Decimal("1.839"), Decimal("1.799")]


def test_new_fuel_at_existing_station_is_appended(conn, snapshot):
    store_snapshot(conn, snapshot)
    later = snapshot.timestamp + timedelta(minutes=30)
    extra = snapshot.prices + [Price(4375, "adblue", Decimal("0.999"))]
    result = store_snapshot(conn, replace(snapshot, timestamp=later, prices=extra))
    assert result.changed == 1


def test_older_snapshot_never_rewrites_history(conn, snapshot):
    store_snapshot(conn, snapshot)
    earlier = snapshot.timestamp - timedelta(minutes=30)
    changed = [replace(p, price=p.price + 1) for p in snapshot.prices]
    result = store_snapshot(conn, replace(snapshot, timestamp=earlier, prices=changed))
    assert result.changed == 0
