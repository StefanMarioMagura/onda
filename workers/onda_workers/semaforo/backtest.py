"""Walk-forward backtest of the semáforo, as a Markdown report.

For each fuel, compares every model variant with the "tomorrow same as today"
baseline using the Brent we would really have (the EIA publishes ~7 days
late), plus v1 with same-day Brent as an ideal reference. All rows of a table
are scored on exactly the same days.

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

from .features import ALL_FEATURES, build_dataset
from .model import CURRENT, V1, VARIANTS, SemaforoModel, class_balance, evaluate, walk_forward

FUELS = {"gasoleo_a": "Gasóleo A", "gasolina_95_e5": "Gasolina 95"}
REAL_LAG = 7    # days the EIA's Brent arrives late
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


def _row(name: str, m) -> str:
    return (f"| {name} | {m.days} | {m.mae_model_cents:.2f} c | {m.mae_baseline_cents:.2f} c "
            f"| {pct(m.skill)} | {pct(m.accuracy_model)} | {pct(m.accuracy_baseline)} "
            f"| {m.verde_days} ({pct(m.verde_hit_rate)}) | {m.rojo_days} ({pct(m.rojo_hit_rate)}) |")


def report(prices: pd.DataFrame, brent: pd.Series) -> str:
    out = ["# Semáforo · backtest", ""]
    first, last = prices["day"].min().date(), prices["day"].max().date()
    out += [f"Precios nacionales del {first} al {last}; Brent del "
            f"{brent.index.min().date()} al {brent.index.max().date()}.",
            f"Validación *walk-forward*: cada año se predice con un modelo entrenado solo con "
            f"los años anteriores ({TEST_YEARS[0]}–{TEST_YEARS[-1]}). Salvo la fila \"ideal\", "
            f"el Brent llega con {REAL_LAG} días de retraso, como en la realidad.", ""]

    for fuel, fuel_name in FUELS.items():
        series = prices[prices["fuel"] == fuel].set_index("day")["avg_price"]
        real = build_dataset(series, brent, brent_lag_days=REAL_LAG).dropna(subset=ALL_FEATURES)
        # Same days for every row: the ideal dataset is cut to the real one's days.
        ideal = build_dataset(series, brent, brent_lag_days=0).reindex(real.index).dropna(subset=["brent_7"])

        out += [f"## {fuel_name}", "",
                "| Modelo | Días | Error modelo | Error referencia | Mejora | Acierto modelo "
                "| Acierto referencia | Verdes (aciertan) | Rojos (aciertan) |",
                "|---|---|---|---|---|---|---|---|---|"]
        out.append(_row(f"{V1.name} — Brent al día (ideal)", evaluate(walk_forward(ideal, TEST_YEARS, V1))))
        results = {v: walk_forward(real, TEST_YEARS, v) for v in VARIANTS}
        for variant, res in results.items():
            out.append(_row(variant.name, evaluate(res)))
        balance = class_balance(results[V1])
        out += ["", f"Reparto real de días: verde {pct(balance['verde'])}, ámbar "
                f"{pct(balance['ambar'])}, rojo {pct(balance['rojo'])}.", ""]

        out += [f"Por año, {CURRENT.name}:", "",
                "| Año | Días | Error modelo | Error referencia | Mejora | Acierto modelo |",
                "|---|---|---|---|---|---|"]
        for year, r in results[CURRENT].groupby("year"):
            m = evaluate(r)
            out.append(f"| {year} | {m.days} | {m.mae_model_cents:.2f} c | "
                       f"{m.mae_baseline_cents:.2f} c | {pct(m.skill)} | {pct(m.accuracy_model)} |")

        coef = SemaforoModel.fit(real, CURRENT).coefficients()
        out += ["", f"Coeficientes de {CURRENT.name} con todos los datos:", "",
                *[f"- `{k}` = {v:+.3f}" for k, v in coef.items() if k != "intercept"],
                "", "(Variación del precio a 7 días, en €/l, por cada €/l de la variable.)", ""]
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
