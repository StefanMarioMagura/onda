"""Semáforo v1: linear regression of the 7-day price change.

change_7d ~ brent_7 + brent_14 + weekday (one-hot, Monday as reference)

Plus the evaluation tools: a walk-forward backtest by year and metrics
against the "tomorrow same as today" baseline (expected change 0, so always
ámbar).
"""

from __future__ import annotations

from dataclasses import dataclass

import pandas as pd
from sklearn.linear_model import LinearRegression

from .features import AMBAR, FEATURES, HORIZON_DAYS, ROJO, VERDE, classify

WEEKDAYS = ["lun", "mar", "mie", "jue", "vie", "sab", "dom"]


def design_matrix(data: pd.DataFrame) -> pd.DataFrame:
    """Brent features plus weekday dummies (Monday is the baseline)."""
    x = data[FEATURES].copy()
    for day in range(1, 7):
        x[f"dia_{WEEKDAYS[day]}"] = (data["weekday"] == day).astype(float)
    return x


@dataclass
class SemaforoModel:
    regression: LinearRegression

    @classmethod
    def fit(cls, data: pd.DataFrame) -> "SemaforoModel":
        train = data.dropna(subset=["change_7d"])
        if train.empty:
            raise ValueError("No rows with a known target to train on")
        return cls(LinearRegression().fit(design_matrix(train), train["change_7d"]))

    def predict(self, data: pd.DataFrame) -> pd.Series:
        """Expected 7-day change in €/l for each row."""
        return pd.Series(self.regression.predict(design_matrix(data)), index=data.index)

    def coefficients(self) -> dict[str, float]:
        names = list(self.regression.feature_names_in_)
        return {"intercept": float(self.regression.intercept_),
                **dict(zip(names, map(float, self.regression.coef_)))}


def walk_forward(data: pd.DataFrame, test_years: list[int]) -> pd.DataFrame:
    """Backtest: for each year, train on everything before it and predict it.

    A training row on day d needs the price of d+7, so rows within 7 days of
    the test year are dropped from training: otherwise the model would have
    seen prices from inside the test period.
    """
    scored = data.dropna(subset=["change_7d"])
    results = []
    for year in test_years:
        start = pd.Timestamp(year=year, month=1, day=1)
        train = scored[scored.index <= start - pd.Timedelta(days=HORIZON_DAYS + 1)]
        test = scored[scored.index.year == year]
        if train.empty or test.empty:
            continue
        model = SemaforoModel.fit(train)
        results.append(pd.DataFrame({
            "change_7d": test["change_7d"],
            "predicted": model.predict(test),
            "actual": test["actual"],
            "year": year,
        }))
    if not results:
        raise ValueError("No test year has both training and test data")
    out = pd.concat(results)
    out["signal"] = out["predicted"].map(classify)
    return out


@dataclass(frozen=True)
class Metrics:
    days: int
    mae_model_cents: float
    mae_baseline_cents: float
    skill: float                 # 1 - MAE_model / MAE_baseline; > 0 beats the baseline
    accuracy_model: float        # signal == actual class
    accuracy_baseline: float     # baseline always says ámbar
    verde_days: int
    verde_hit_rate: float        # when it says verde, how often prices really rose > 1 cent
    rojo_days: int
    rojo_hit_rate: float


def _hit_rate(results: pd.DataFrame, signal: str) -> tuple[int, float]:
    said = results[results["signal"] == signal]
    return len(said), float((said["actual"] == signal).mean()) if len(said) else float("nan")


def evaluate(results: pd.DataFrame) -> Metrics:
    """Compare the model with "tomorrow same as today" (change 0 → ámbar)."""
    error_model = (results["predicted"] - results["change_7d"]).abs().mean()
    error_baseline = results["change_7d"].abs().mean()
    verde_days, verde_hits = _hit_rate(results, VERDE)
    rojo_days, rojo_hits = _hit_rate(results, ROJO)
    return Metrics(
        days=len(results),
        mae_model_cents=float(error_model * 100),
        mae_baseline_cents=float(error_baseline * 100),
        skill=float(1 - error_model / error_baseline) if error_baseline else float("nan"),
        accuracy_model=float((results["signal"] == results["actual"]).mean()),
        accuracy_baseline=float((results["actual"] == AMBAR).mean()),
        verde_days=verde_days,
        verde_hit_rate=verde_hits,
        rojo_days=rojo_days,
        rojo_hit_rate=rojo_hits,
    )


def class_balance(results: pd.DataFrame) -> dict[str, float]:
    shares = results["actual"].value_counts(normalize=True)
    return {c: float(shares.get(c, 0.0)) for c in (VERDE, AMBAR, ROJO)}
