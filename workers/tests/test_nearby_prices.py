"""Integration tests for the nearby_prices SQL function (used by the app)."""

import json
from dataclasses import replace
from datetime import timedelta
from decimal import Decimal
from pathlib import Path

import pytest

from onda_workers.db import store_snapshot
from onda_workers.ministerio import parse_snapshot

from .conftest import requires_db

pytestmark = requires_db

FIXTURE = Path(__file__).parent / "fixtures" / "estaciones_sample.json"
# Albacete city centre: stations 4375 (~39.2114, -1.5392... in La Roda) and 14123 nearby.
ALBACETE = (38.9943, -1.8585)


@pytest.fixture
def stations(conn):
    snapshot = parse_snapshot(json.loads(FIXTURE.read_text(encoding="utf-8")))
    store_snapshot(conn, snapshot)
    # The fixture is from a fixed date; make the stations "currently listed".
    conn.execute("update public.gasolineras set last_seen_at = now()")
    return snapshot


def call(conn, fuel="gasoleo_a", point=ALBACETE, radius=60, limit=5):
    return conn.execute(
        "select station_id, price, distance_km from public.nearby_prices(%s, %s, %s, %s, %s)",
        (fuel, *point, radius, limit),
    ).fetchall()


def test_returns_nearby_stations_cheapest_first(conn, stations):
    rows = call(conn)
    assert [r[0] for r in rows] == [4375, 14123]          # 1.839 then 1.955; Tenerife is far away
    assert [r[1] for r in rows] == [Decimal("1.839"), Decimal("1.955")]
    assert all(r[2] < 60 for r in rows)


def test_uses_the_latest_price_of_each_station(conn, stations):
    later = replace(
        stations,
        timestamp=stations.timestamp + timedelta(minutes=30),
        prices=[replace(p, price=Decimal("1.799")) if (p.station_id, p.fuel) == (14123, "gasoleo_a") else p
                for p in stations.prices],
    )
    store_snapshot(conn, later)
    assert call(conn)[0][:2] == (14123, Decimal("1.799"))


def test_radius_and_limit(conn, stations):
    assert call(conn, radius=1) == []
    assert len(call(conn, limit=1)) == 1


def test_radius_is_capped_at_50_km(conn, stations):
    # Tenerife is ~1,700 km away: even a huge radius must not reach it.
    assert 13639 not in [r[0] for r in call(conn, radius=5000)]


def test_skips_stations_no_longer_listed(conn, stations):
    conn.execute("update public.gasolineras set last_seen_at = now() - interval '4 days' where id = 4375")
    assert [r[0] for r in call(conn)] == [14123]


def test_skips_restricted_sale_stations(conn, stations):
    conn.execute("update public.gasolineras set sale_type = 'R' where id = 4375")
    assert [r[0] for r in call(conn)] == [14123]


def test_fuel_not_sold_returns_nothing(conn, stations):
    assert call(conn, fuel="hidrogeno") == []


def test_returns_the_average_of_the_whole_area(conn, stations):
    rows = conn.execute(
        "select station_id, area_avg_price, area_station_count"
        " from public.nearby_prices('gasoleo_a', %s, %s, 60, 1)", ALBACETE).fetchall()
    # Only the cheapest is returned, but the average covers both nearby stations.
    assert rows == [(4375, Decimal("1.897"), 2)]
