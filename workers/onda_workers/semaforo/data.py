"""Loading the semáforo's inputs from Supabase."""

from __future__ import annotations

import pandas as pd
import psycopg

FUELS = {"gasoleo_a": "Gasóleo A", "gasolina_95_e5": "Gasolina 95"}


def load_series(conn: psycopg.Connection, fuels: list[str]) -> tuple[pd.DataFrame, pd.Series]:
    """National daily average prices (day, fuel, avg_price) and Brent in €/barrel by day."""
    prices = pd.DataFrame(
        conn.execute(
            "select day, fuel, avg_price from public.precios_diarios"
            " where province_id = '00' and fuel = any(%s) order by day",
            (fuels,),
        ).fetchall(),
        columns=["day", "fuel", "avg_price"],
    )
    brent = pd.DataFrame(
        conn.execute("select day, brent_eur from public.brent_diario order by day").fetchall(),
        columns=["day", "brent_eur"],
    )
    prices["day"] = pd.to_datetime(prices["day"])
    prices["avg_price"] = prices["avg_price"].astype(float)
    brent["day"] = pd.to_datetime(brent["day"])
    return prices, brent.set_index("day")["brent_eur"].astype(float)
