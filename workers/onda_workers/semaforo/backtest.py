"""Walk-forward backtest of the semáforo v1, as a Markdown report.

Compares, for each fuel, the model with the "tomorrow same as today" baseline,
both with Brent known up to the same day (lag 0, ideal) and with the EIA's
real publication delay (lag 7).

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.semaforo.backtest > report.md
    python -m onda_workers.semaforo.backtest --prices precios.csv --brent brent.csv > report.md

CSV inputs: prices with columns day,fuel,avg_price (national, province '00');
Brent with columns day,brent_eur.
"""

from __future__ import annotations

import argparse
import os
import sys

import pandas as pd

from .features import build_dataset
from .model import SemaforoModel, class_balance, evaluate, walk_forward

FUELS = {"gasoleo_a": "Gasóleo A", "gasolina_95_e5": "Gasolina 95"}
LAGS = {0: "Brent al día (ideal)", 7: "Brent con 7 días de retraso (real)"}
TEST_YEARS = [2021, 2022, 2023, 2024, 2025, 2026]


def load_csv(prices_path: str, brent_path: str) -> tuple[pd.DataFrame, pd.Series]:
    prices = pd.read_csv(prices_path, parse_dates=["day"])
    brent = pd.read_csv(brent_path, parse_dates=["day"]).set_index("day")["brent_eur"]
    return prices, brent


def load_db(database_url: str) -> tuple[pd.DataFrame, pd.Series]:
    import psycopg

    with psycopg.connect(database_url, prepare_threshold=None) as conn:
        prices = pd.DataFrame(
            conn.execute(
                "select day, fuel, avg_price from public.precios_diarios"
                " where province_id = '00' and fuel = any(%s) order by day",
                (list(FUELS),),
            ).fetchall(),
            columns=["day", "fuel", "avg_price"],
        )
        brent = pd.DataFrame(
            conn.execute("select day, brent_eur from public.brent_diario order by day").fetchall(),
            columns=["day", "brent_eur"],
        )
    prices["day"] = pd.to_datetime(prices["day"])
    brent["day"] = pd.to_datetime(brent["day"])
    return prices, brent.set_index("day")["brent_eur"]


def pct(x: float) -> str:
    return "–" if x != x else f"{x:.0%}"


def report(prices: pd.DataFrame, brent: pd.Series) -> str:
    out = ["# Semáforo v1 · backtest", ""]
    first, last = prices["day"].min().date(), prices["day"].max().date()
    out += [f"Precios nacionales del {first} al {last}; Brent del "
            f"{brent.index.min().date()} al {brent.index.max().date()}.",
            f"Validación *walk-forward*: cada año se predice con un modelo entrenado solo con "
            f"los años anteriores ({TEST_YEARS[0]}–{TEST_YEARS[-1]}).", ""]

    for fuel, fuel_name in FUELS.items():
        series = prices[prices["fuel"] == fuel].set_index("day")["avg_price"]
        out += [f"## {fuel_name}", ""]
        out += ["| Brent | Días | Error modelo | Error referencia | Mejora | Acierto modelo "
                "| Acierto referencia | Verdes (aciertan) | Rojos (aciertan) |",
                "|---|---|---|---|---|---|---|---|---|"]
        balance = None
        per_year = {}
        for lag, lag_name in LAGS.items():
            data = build_dataset(series, brent, brent_lag_days=lag)
            results = walk_forward(data, TEST_YEARS)
            m = evaluate(results)
            balance = class_balance(results)
            per_year[lag] = {y: evaluate(r) for y, r in results.groupby("year")}
            out.append(
                f"| {lag_name} | {m.days} | {m.mae_model_cents:.2f} c | {m.mae_baseline_cents:.2f} c "
                f"| {pct(m.skill)} | {pct(m.accuracy_model)} | {pct(m.accuracy_baseline)} "
                f"| {m.verde_days} ({pct(m.verde_hit_rate)}) | {m.rojo_days} ({pct(m.rojo_hit_rate)}) |")
        out += ["", f"Reparto real de días: verde {pct(balance['verde'])}, ámbar "
                f"{pct(balance['ambar'])}, rojo {pct(balance['rojo'])}.", ""]

        out += ["Mejora sobre la referencia por año (Brent con retraso real):", "",
                "| Año | Días | Error modelo | Error referencia | Mejora | Acierto modelo |",
                "|---|---|---|---|---|---|"]
        for year, m in per_year[7].items():
            out.append(f"| {year} | {m.days} | {m.mae_model_cents:.2f} c | "
                       f"{m.mae_baseline_cents:.2f} c | {pct(m.skill)} | {pct(m.accuracy_model)} |")

        final = SemaforoModel.fit(build_dataset(series, brent, brent_lag_days=7))
        coef = final.coefficients()
        out += ["", "Coeficientes con todos los datos (retraso real):", "",
                f"- `brent_7` = {coef['brent_7']:.3f}, `brent_14` = {coef['brent_14']:.3f}: "
                f"céntimos en el surtidor por céntimo/litro de Brent en cada ventana.",
                "- Día de la semana (vs. lunes, en céntimos): " + ", ".join(
                    f"{k.removeprefix('dia_')} {v * 100:+.2f}" for k, v in coef.items()
                    if k.startswith("dia_")),
                ""]
    out += ["*Error* = error absoluto medio del cambio de precio a 7 días. *Mejora* = "
            "1 − error modelo / error referencia. La referencia es \"mañana igual que hoy\": "
            "cambio 0, siempre ámbar.", ""]
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--prices", help="CSV day,fuel,avg_price (instead of the database)")
    parser.add_argument("--brent", help="CSV day,brent_eur (instead of the database)")
    args = parser.parse_args(argv)

    if args.prices and args.brent:
        prices, brent = load_csv(args.prices, args.brent)
    elif os.environ.get("DATABASE_URL"):
        prices, brent = load_db(os.environ["DATABASE_URL"])
    else:
        print("Give --prices and --brent, or set DATABASE_URL", file=sys.stderr)
        return 2
    print(report(prices, brent))
    return 0


if __name__ == "__main__":
    sys.exit(main())
