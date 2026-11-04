"""Tests for the Brent/EUR-USD worker: parsers, calendar join and storage."""

import json
from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest

from onda_workers.brent import (
    BrentDay,
    SourceError,
    combine,
    last_day,
    parse_ecb_csv,
    parse_eia,
    store,
)

from .conftest import requires_db

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture
def eia_payload():
    return json.loads((FIXTURES / "eia_brent_sample.json").read_text())


@pytest.fixture
def ecb_text():
    return (FIXTURES / "ecb_usd_sample.csv").read_text()


# --- parse_eia ------------------------------------------------------------

def test_parse_eia_real_sample(eia_payload):
    prices = parse_eia(eia_payload)
    assert len(prices) == 8
    assert prices[date(2025, 12, 22)] == Decimal("62.22")
    assert prices[date(2026, 1, 5)] == Decimal("63")
    assert date(2025, 12, 25) not in prices          # Christmas: no trading


def test_parse_eia_drops_unusable_values_and_other_series(eia_payload):
    rows = eia_payload["response"]["data"]
    rows[0]["value"] = None
    rows[1]["value"] = "NA"
    rows[2]["series"] = "RWTC"                         # WTI, not Brent
    assert len(parse_eia(eia_payload)) == 5


def test_parse_eia_error_response():
    with pytest.raises(SourceError, match="API_KEY_INVALID"):
        parse_eia({"error": {"code": "API_KEY_INVALID", "message": "..."}})


def test_parse_eia_malformed_response():
    with pytest.raises(SourceError):
        parse_eia({"warnings": []})


# --- parse_ecb_csv --------------------------------------------------------

def test_parse_ecb_real_sample(ecb_text):
    rates = parse_ecb_csv(ecb_text)
    assert len(rates) == 8
    assert rates[date(2025, 12, 22)] == Decimal("1.1745")
    assert date(2025, 12, 25) not in rates and date(2026, 1, 1) not in rates


def test_parse_ecb_skips_empty_observations():
    text = "TIME_PERIOD,OBS_VALUE\n2026-01-02,1.1721\n2026-01-05,\n"
    assert parse_ecb_csv(text) == {date(2026, 1, 2): Decimal("1.1721")}


def test_parse_ecb_rejects_unexpected_format():
    with pytest.raises(SourceError):
        parse_ecb_csv("<html>maintenance</html>")


# --- combine --------------------------------------------------------------

def test_combine_real_samples_same_day_rates(eia_payload, ecb_text):
    rows = combine(parse_eia(eia_payload), parse_ecb_csv(ecb_text))
    assert len(rows) == 8
    first = rows[0]
    assert (first.day, first.fx_day) == (date(2025, 12, 22), date(2025, 12, 22))
    assert first.brent_eur == Decimal("52.976")       # 62.22 / 1.1745


def test_combine_uses_previous_rate_when_ecb_is_closed():
    brent = {date(2026, 1, 1): Decimal("61.00")}       # say Brent traded, ECB closed
    rates = {date(2025, 12, 31): Decimal("1.1750"), date(2026, 1, 2): Decimal("1.1721")}
    [row] = combine(brent, rates)
    assert row.fx_day == date(2025, 12, 31)
    assert row.usd_per_eur == Decimal("1.1750")


def test_combine_never_uses_a_future_rate():
    brent = {date(2026, 1, 5): Decimal("63")}
    rates = {date(2026, 1, 6): Decimal("1.17")}
    assert combine(brent, rates) == []


def test_combine_skips_days_with_stale_rate():
    brent = {date(2026, 1, 20): Decimal("63")}
    rates = {date(2026, 1, 12): Decimal("1.17")}      # 8 days old
    assert combine(brent, rates) == []


def test_combine_is_sorted_by_day():
    brent = {date(2026, 1, 5): Decimal("63"), date(2026, 1, 2): Decimal("61.98")}
    rates = {date(2026, 1, 2): Decimal("1.1721")}
    assert [r.day for r in combine(brent, rates)] == [date(2026, 1, 2), date(2026, 1, 5)]


# --- storage (integration) ------------------------------------------------

def row(day, usd="63.000", fx="1.17000"):
    return BrentDay(day, Decimal(usd), Decimal(fx), day)


@requires_db
def test_store_inserts_and_db_computes_brent_eur(conn, eia_payload, ecb_text):
    rows = combine(parse_eia(eia_payload), parse_ecb_csv(ecb_text))
    assert store(conn, rows) == 8
    assert last_day(conn) == date(2026, 1, 5)
    db_eur = dict(conn.execute("select day, brent_eur from public.brent_diario").fetchall())
    assert db_eur == {r.day: r.brent_eur for r in rows}


@requires_db
def test_store_upsert_only_touches_changed_days(conn):
    d1, d2 = date(2026, 1, 2), date(2026, 1, 5)
    store(conn, [row(d1), row(d2)])
    assert store(conn, [row(d1), row(d2)]) == 0                  # nothing changed
    assert store(conn, [row(d1), row(d2, usd="64.500")]) == 1    # EIA revised d2
    assert conn.execute(
        "select brent_usd from public.brent_diario where day = %s", (d2,)
    ).fetchone()[0] == Decimal("64.500")


@requires_db
def test_last_day_empty_table(conn):
    assert last_day(conn) is None
