"""Client and parser for the Ministry's fuel price REST API (Geoportal de Gasolineras).

The API returns every station in mainland Spain + Baleares + Canarias with the
prices in force at that moment. It refreshes every 30 minutes.

Quirks handled here:
- Decimals use a comma ("1,839") and missing prices are empty strings.
- "Fecha" is when the response was generated (≈ request time), in Madrid
  local time without an offset. It is not when prices last changed.
- The body may start with a UTF-8 BOM.
"""

from __future__ import annotations

import json
import logging
import re
import ssl
import unicodedata
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal, InvalidOperation
from typing import Any
from zoneinfo import ZoneInfo

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

log = logging.getLogger(__name__)

API_URL = (
    "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/"
    "PreciosCarburantes/EstacionesTerrestres/"
)
MADRID = ZoneInfo("Europe/Madrid")
PRICE_PREFIX = "Precio "

# Short, stable codes for the fuels we care most about. Any other "Precio X"
# field is still stored, under an automatic slug (see fuel_code()).
FUEL_CODES = {
    "Gasoleo A": "gasoleo_a",
    "Gasoleo B": "gasoleo_b",
    "Gasoleo Premium": "gasoleo_premium",
    "Gasolina 95 E5": "gasolina_95_e5",
    "Gasolina 95 E10": "gasolina_95_e10",
    "Gasolina 95 E5 Premium": "gasolina_95_e5_premium",
    "Gasolina 98 E5": "gasolina_98_e5",
    "Gasolina 98 E10": "gasolina_98_e10",
    "Gases licuados del petróleo": "glp",
    "Gas Natural Comprimido": "gnc",
    "Gas Natural Licuado": "gnl",
    "Diésel Renovable": "diesel_renovable",
    "Adblue": "adblue",
}

# Bounding box around Spain including Canarias; anything outside is bad data.
LAT_RANGE = (27.0, 44.5)
LON_RANGE = (-18.5, 4.5)


class MinisterioError(RuntimeError):
    """The API answered, but not with a usable snapshot."""


@dataclass(frozen=True)
class Station:
    id: int
    brand: str
    address: str
    postal_code: str | None
    locality: str | None
    municipality: str | None
    province: str | None
    municipality_id: str | None
    province_id: str | None
    region_id: str | None
    opening_hours: str | None
    road_side: str | None
    sale_type: str | None
    latitude: float
    longitude: float


@dataclass(frozen=True)
class Price:
    station_id: int
    fuel: str
    price: Decimal


@dataclass(frozen=True)
class Snapshot:
    timestamp: datetime
    stations: list[Station]
    prices: list[Price]
    skipped_stations: int


# --------------------------------------------------------------------------
# Field parsers
# --------------------------------------------------------------------------

def parse_decimal(raw: str | None) -> Decimal | None:
    """'1,839' -> Decimal('1.839'); '' or None -> None."""
    if raw is None:
        return None
    text = raw.strip().replace(",", ".")
    if not text:
        return None
    try:
        return Decimal(text)
    except InvalidOperation:
        return None


def parse_timestamp(raw: str) -> datetime:
    """'03/11/2026 21:17:07' (Madrid local time) -> timezone-aware datetime."""
    naive = datetime.strptime(raw.strip(), "%d/%m/%Y %H:%M:%S")
    return naive.replace(tzinfo=MADRID)


def fuel_code(field_name: str) -> str:
    """'Precio Gasoleo A' -> 'gasoleo_a'. Unknown fuels get an ASCII slug."""
    name = field_name.removeprefix(PRICE_PREFIX).strip()
    if name in FUEL_CODES:
        return FUEL_CODES[name]
    ascii_name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", ascii_name.lower()).strip("_")


def _text(record: dict[str, Any], key: str) -> str | None:
    value = (record.get(key) or "").strip()
    return value or None


# --------------------------------------------------------------------------
# Snapshot parser
# --------------------------------------------------------------------------

def parse_station(record: dict[str, Any]) -> Station | None:
    """Return the station, or None if it lacks an id or valid coordinates."""
    try:
        station_id = int(record["IDEESS"])
    except (KeyError, TypeError, ValueError):
        return None

    lat = parse_decimal(record.get("Latitud"))
    lon = parse_decimal(record.get("Longitud (WGS84)"))
    if lat is None or lon is None:
        return None
    lat_f, lon_f = float(lat), float(lon)
    if not (LAT_RANGE[0] <= lat_f <= LAT_RANGE[1] and LON_RANGE[0] <= lon_f <= LON_RANGE[1]):
        return None

    return Station(
        id=station_id,
        brand=_text(record, "Rótulo") or "",
        address=_text(record, "Dirección") or "",
        postal_code=_text(record, "C.P."),
        locality=_text(record, "Localidad"),
        municipality=_text(record, "Municipio"),
        province=_text(record, "Provincia"),
        municipality_id=_text(record, "IDMunicipio"),
        province_id=_text(record, "IDProvincia"),
        region_id=_text(record, "IDCCAA"),
        opening_hours=_text(record, "Horario"),
        road_side=_text(record, "Margen"),
        sale_type=_text(record, "Tipo Venta"),
        latitude=lat_f,
        longitude=lon_f,
    )


def parse_prices(station_id: int, record: dict[str, Any]) -> list[Price]:
    """Every non-empty, positive 'Precio X' field becomes a Price."""
    prices = []
    for key, raw in record.items():
        if not key.startswith(PRICE_PREFIX):
            continue
        value = parse_decimal(raw)
        if value is None or value <= 0:
            continue
        prices.append(Price(station_id=station_id, fuel=fuel_code(key), price=value))
    return prices


def parse_snapshot(payload: dict[str, Any]) -> Snapshot:
    if payload.get("ResultadoConsulta") != "OK":
        raise MinisterioError(f"Unexpected ResultadoConsulta: {payload.get('ResultadoConsulta')!r}")
    records = payload.get("ListaEESSPrecio")
    if not isinstance(records, list) or not records:
        raise MinisterioError("Snapshot has no stations")

    stations: list[Station] = []
    prices: list[Price] = []
    seen: set[int] = set()
    skipped = 0
    for record in records:
        station = parse_station(record)
        if station is None or station.id in seen:
            skipped += 1
            continue
        seen.add(station.id)
        stations.append(station)
        prices.extend(parse_prices(station.id, record))

    return Snapshot(
        timestamp=parse_timestamp(payload["Fecha"]),
        stations=stations,
        prices=prices,
        skipped_stations=skipped,
    )


# --------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------

# Some of the Ministry's servers only accept TLS 1.2 with RSA key exchange
# (AES*-GCM-SHA*, no forward secrecy). Python's default context leaves those
# ciphers out, so the handshake fails depending on which server answers
# ("Connection reset" / "UNEXPECTED_EOF"). We add just those two on top of
# the defaults. Certificates are still verified; the data is public and we
# send nothing secret, so losing forward secrecy here costs nothing.
LEGACY_CIPHERS = ("AES256-GCM-SHA384", "AES128-GCM-SHA256")


def ssl_context() -> ssl.SSLContext:
    context = ssl.create_default_context()
    tls12 = [c["name"] for c in context.get_ciphers() if c["protocol"] == "TLSv1.2"]
    context.set_ciphers(":".join([*tls12, *LEGACY_CIPHERS]))
    return context


class _MinisterioAdapter(HTTPAdapter):
    def init_poolmanager(self, *args: Any, **kwargs: Any) -> None:
        kwargs["ssl_context"] = ssl_context()
        super().init_poolmanager(*args, **kwargs)


def _session() -> requests.Session:
    retry = Retry(total=4, backoff_factor=5, status_forcelist=(429, 500, 502, 503, 504))
    session = requests.Session()
    session.mount("https://", _MinisterioAdapter(max_retries=retry))
    session.headers.update({"Accept": "application/json", "User-Agent": "onda-workers/0.1"})
    return session


def fetch_snapshot(url: str = API_URL, timeout: float = 120) -> Snapshot:
    response = _session().get(url, timeout=timeout)
    response.raise_for_status()
    payload = json.loads(response.content.decode("utf-8-sig"))
    return parse_snapshot(payload)
