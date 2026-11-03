import json
from datetime import datetime, timedelta
from decimal import Decimal
from pathlib import Path

import pytest

from onda_workers.ministerio import (
    MinisterioError,
    fuel_code,
    parse_decimal,
    parse_prices,
    parse_snapshot,
    parse_station,
    parse_timestamp,
)

FIXTURE = Path(__file__).parent / "fixtures" / "estaciones_sample.json"


@pytest.fixture
def payload():
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


# --- parse_decimal --------------------------------------------------------

@pytest.mark.parametrize(
    "raw, expected",
    [
        ("1,839", Decimal("1.839")),
        ("39,211417", Decimal("39.211417")),
        ("-1,539167", Decimal("-1.539167")),
        (" 1,5 ", Decimal("1.5")),
        ("", None),
        ("   ", None),
        (None, None),
        ("n/d", None),
    ],
)
def test_parse_decimal(raw, expected):
    assert parse_decimal(raw) == expected


# --- parse_timestamp ------------------------------------------------------

def test_parse_timestamp_winter_is_utc_plus_1():
    ts = parse_timestamp("03/11/2026 21:17:07")
    assert ts.utcoffset() == timedelta(hours=1)
    assert ts.replace(tzinfo=None) == datetime(2026, 11, 3, 21, 17, 7)


def test_parse_timestamp_summer_is_utc_plus_2():
    assert parse_timestamp("15/07/2026 10:00:00").utcoffset() == timedelta(hours=2)


def test_parse_timestamp_rejects_garbage():
    with pytest.raises(ValueError):
        parse_timestamp("2026-11-03T21:17:07")


# --- fuel_code ------------------------------------------------------------

@pytest.mark.parametrize(
    "field, code",
    [
        ("Precio Gasoleo A", "gasoleo_a"),
        ("Precio Gasolina 95 E5", "gasolina_95_e5"),
        ("Precio Gases licuados del petróleo", "glp"),
        ("Precio Diésel Renovable", "diesel_renovable"),
        # Unknown fuels still get a stable ASCII code.
        ("Precio Hidrogeno", "hidrogeno"),
        ("Precio Biogás Natural Comprimido", "biogas_natural_comprimido"),
    ],
)
def test_fuel_code(field, code):
    assert fuel_code(field) == code


# --- parse_station / parse_prices -----------------------------------------

def test_parse_station_from_real_record(payload):
    station = parse_station(payload["ListaEESSPrecio"][0])
    assert station is not None
    assert station.id == 4375
    assert station.province == "ALBACETE"
    assert station.latitude == pytest.approx(39.211417)
    assert station.longitude == pytest.approx(-1.539167)
    assert station.road_side == "D"
    assert station.sale_type == "P"


def test_parse_station_accepts_canarias(payload):
    station = parse_station(payload["ListaEESSPrecio"][1])
    assert station is not None
    assert station.province == "SANTA CRUZ DE TENERIFE"


@pytest.mark.parametrize(
    "override",
    [
        {"Latitud": ""},
        {"Longitud (WGS84)": ""},
        {"Latitud": "0,0", "Longitud (WGS84)": "0,0"},  # null island
        {"IDEESS": ""},
    ],
)
def test_parse_station_rejects_bad_records(payload, override):
    record = {**payload["ListaEESSPrecio"][0], **override}
    assert parse_station(record) is None


def test_parse_prices_keeps_only_non_empty_positive(payload):
    record = {**payload["ListaEESSPrecio"][0], "Precio Gasoleo Premium": "0,000"}
    prices = {p.fuel: p.price for p in parse_prices(4375, record)}
    assert prices == {
        "gasoleo_a": Decimal("1.839"),
        "gasoleo_b": Decimal("1.589"),
        "gasolina_95_e5": Decimal("1.699"),
    }


# --- parse_snapshot -------------------------------------------------------

def test_parse_snapshot(payload):
    snapshot = parse_snapshot(payload)
    assert [s.id for s in snapshot.stations] == [4375, 13639, 14123]
    assert len(snapshot.prices) == 3 + 2 + 5
    assert snapshot.skipped_stations == 0
    assert snapshot.timestamp == parse_timestamp(payload["Fecha"])
    assert any(p.fuel == "glp" for p in snapshot.prices)


def test_parse_snapshot_skips_duplicates_and_invalid(payload):
    records = payload["ListaEESSPrecio"]
    payload["ListaEESSPrecio"] = records + [records[0], {**records[1], "Latitud": ""}]
    snapshot = parse_snapshot(payload)
    assert len(snapshot.stations) == 3
    assert snapshot.skipped_stations == 2


def test_parse_snapshot_rejects_error_result(payload):
    payload["ResultadoConsulta"] = "ERROR"
    with pytest.raises(MinisterioError):
        parse_snapshot(payload)


def test_parse_snapshot_rejects_empty(payload):
    payload["ListaEESSPrecio"] = []
    with pytest.raises(MinisterioError):
        parse_snapshot(payload)
