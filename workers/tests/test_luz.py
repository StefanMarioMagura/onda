"""Tests for the PVPC electricity price worker."""

import json
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from onda_workers.luz import HourPrice, REEError, parse_pvpc, store

from .conftest import requires_db

FIXTURE = Path(__file__).parent / "fixtures" / "ree_precios_sample.json"
MADRID = ZoneInfo("Europe/Madrid")


@pytest.fixture
def payload():
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def test_parse_real_response_has_24_hours(payload):
    prices = parse_pvpc(payload)
    assert len(prices) == 24
    assert prices[0].hour == datetime(2026, 11, 5, 0, tzinfo=MADRID)
    assert prices[0].eur_mwh == Decimal("214.17")
    assert prices[-1].hour.hour == 23


def test_parse_ignores_the_spot_market_series(payload):
    # The response also has the 15-minute spot price (96 values): only PVPC counts.
    assert all(p.hour.minute == 0 for p in parse_pvpc(payload))


def test_parse_skips_missing_values(payload):
    payload["included"][0]["attributes"]["values"][3]["value"] = None
    assert len(parse_pvpc(payload)) == 23


def test_parse_without_pvpc_fails(payload):
    payload["included"] = [s for s in payload["included"] if s["type"] != "PVPC"]
    with pytest.raises(REEError):
        parse_pvpc(payload)


@requires_db
def test_store_is_idempotent_and_updates_changes(conn, payload):
    prices = parse_pvpc(payload)
    assert store(conn, prices) == 24
    assert store(conn, prices) == 0
    first = prices[0]
    assert store(conn, [HourPrice(first.hour, Decimal("100.00"))]) == 1
    value = conn.execute("select pvpc_eur_mwh from public.luz_horaria where hour = %s", (first.hour,)).fetchone()[0]
    assert value == Decimal("100.00")
