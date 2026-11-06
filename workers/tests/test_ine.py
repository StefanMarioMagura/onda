"""Tests for the INE statistics worker (CPI and salaries)."""

import json
from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest

from onda_workers.ine import SERIES, INEError, Point, parse_series, store

from .conftest import requires_db

FIXTURES = Path(__file__).parent / "fixtures"


def load(name):
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def test_monthly_cpi_periods_are_first_of_month():
    points = parse_series(load("ine_ipc_alimentos_sample.json"), "IPC290754")
    assert len(points) == 13
    assert points[0] == Point(date(2025, 9, 1), Decimal("2.4"))
    assert points[-1].periodo == date(2026, 9, 1)
    assert all(p.periodo.day == 1 for p in points)


def test_annual_salary_periods_are_first_of_january():
    points = parse_series(load("ine_salario_medio_sample.json"), "EAES741")
    assert [p.periodo for p in points] == [date(2022, 1, 1), date(2023, 1, 1), date(2024, 1, 1)]
    assert points[-1].valor == Decimal("29540.26")


def test_secret_and_missing_values_are_skipped():
    payload = load("ine_ipc_alimentos_sample.json")
    payload["Data"][0]["Secreto"] = True
    payload["Data"][1]["Valor"] = None
    assert len(parse_series(payload, "IPC290754")) == 11


def test_wrong_series_is_rejected():
    with pytest.raises(INEError):
        parse_series(load("ine_salario_medio_sample.json"), "IPC290754")


def test_series_catalog_has_unique_names_and_codes():
    assert len({s.name for s in SERIES}) == len(SERIES)
    assert len({s.code for s in SERIES}) == len(SERIES)


@requires_db
def test_store_upserts_and_keeps_revisions(conn):
    series = next(s for s in SERIES if s.name == "salario_medio")
    points = parse_series(load("ine_salario_medio_sample.json"), "EAES741")
    assert store(conn, series, points) == 3
    assert store(conn, series, points) == 0                        # unchanged
    revised = [*points[:-1], Point(points[-1].periodo, Decimal("29600.00"))]
    assert store(conn, series, revised) == 1                       # INE revised 2024
    row = conn.execute(
        "select valor, fuente from public.indicadores where serie = 'salario_medio' and periodo = '2024-01-01'"
    ).fetchone()
    assert row == (Decimal("29600.0000"), "INE:EAES741")
