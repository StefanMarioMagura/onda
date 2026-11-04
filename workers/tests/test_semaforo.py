"""Tests for the semáforo v1: classification, features (no look-ahead), model and backtest."""

import numpy as np
import pandas as pd
import pytest

from onda_workers.semaforo.features import (
    AMBAR,
    LITRES_PER_BARREL,
    ROJO,
    VERDE,
    build_dataset,
    classify,
    to_daily,
)
from onda_workers.semaforo.model import SemaforoModel, class_balance, evaluate, walk_forward


def days(start, n):
    return pd.date_range(start, periods=n, freq="D")


# --- classify -------------------------------------------------------------

@pytest.mark.parametrize("change, expected", [
    (0.0101, VERDE),
    (0.0100, AMBAR),      # exactly 1 cent is not "more than 1 cent"
    (0.0, AMBAR),
    (-0.0100, AMBAR),
    (-0.0101, ROJO),
    (0.08, VERDE),
    (-0.08, ROJO),
])
def test_classify_thresholds(change, expected):
    assert classify(change) == expected


# --- to_daily -------------------------------------------------------------

def test_to_daily_fills_weekends_only_when_asked():
    friday, monday = pd.Timestamp("2024-03-01"), pd.Timestamp("2024-03-04")
    series = pd.Series([80.0, 82.0], index=[friday, monday])
    filled = to_daily(series, fill=True)
    assert list(filled) == [80.0, 80.0, 80.0, 82.0]
    gaps = to_daily(series, fill=False)
    assert gaps.isna().sum() == 2


# --- build_dataset --------------------------------------------------------

def flat_prices(n=60, start="2024-01-01", value=1.5):
    return pd.Series(value, index=days(start, n))


def brent_step(n=60, start="2024-01-01", step_day=30, before=70.0, after=80.0):
    idx = days(start, n)
    return pd.Series(np.where(np.arange(n) < step_day, before, after), index=idx)


def test_target_is_price_in_seven_days_minus_today():
    prices = pd.Series(np.arange(60) * 0.001 + 1.5, index=days("2024-01-01", 60))
    data = build_dataset(prices, brent_step(), brent_lag_days=0)
    assert data["change_7d"].dropna().round(6).eq(0.007).all()
    assert data["change_7d"].isna().sum() == 7       # last week: unknown future


def test_price_gaps_are_not_filled_into_the_target():
    prices = flat_prices()
    prices = prices.drop(pd.Timestamp("2024-02-10"))
    data = build_dataset(prices, brent_step(), brent_lag_days=0)
    assert np.isnan(data.loc["2024-02-03", "change_7d"])    # needs 2024-02-10


def test_brent_features_in_euros_per_litre():
    data = build_dataset(flat_prices(), brent_step(), brent_lag_days=0)
    jump = (80.0 - 70.0) / LITRES_PER_BARREL
    step = pd.Timestamp("2024-01-31")                  # day index 30
    assert data.loc[step, "brent_7"] == pytest.approx(jump)
    assert data.loc[step + pd.Timedelta(days=7), "brent_7"] == 0
    assert data.loc[step + pd.Timedelta(days=7), "brent_14"] == pytest.approx(jump)


@pytest.mark.parametrize("lag", [0, 3, 7])
def test_no_look_ahead_brent_jump_only_visible_after_lag(lag):
    """A Brent jump on day S must not affect any feature before S + lag."""
    data = build_dataset(flat_prices(), brent_step(), brent_lag_days=lag)
    step = pd.Timestamp("2024-01-31")
    before = data[data.index < step + pd.Timedelta(days=lag)]
    assert (before[["brent_7", "brent_14"]] == 0).all().all()
    assert data.loc[step + pd.Timedelta(days=lag), "brent_7"] > 0


def test_rows_without_enough_brent_history_are_dropped():
    data = build_dataset(flat_prices(), brent_step(), brent_lag_days=7)
    # 14 days of Brent changes + 7 days of publication lag
    assert data.index.min() == pd.Timestamp("2024-01-01") + pd.Timedelta(days=21)


def test_actual_class_comes_from_the_real_change():
    prices = flat_prices()
    prices.loc["2024-02-15":] = 1.53                    # +3 cents
    data = build_dataset(prices, brent_step(), brent_lag_days=0)
    assert data.loc["2024-02-10", "actual"] == VERDE
    assert data.loc["2024-01-25", "actual"] == AMBAR


# --- model ----------------------------------------------------------------

def synthetic(n=900, seed=0, pass_through=0.6, noise=0.002):
    """Prices that follow Brent with a known pass-through plus a weekday effect."""
    rng = np.random.default_rng(seed)
    idx = days("2019-01-01", n)
    brent = pd.Series(70 + rng.normal(0, 1.5, n).cumsum(), index=idx)
    data = build_dataset(pd.Series(1.5, index=idx), brent, brent_lag_days=0)
    effect = pass_through * data["brent_7"] + 0.002 * (data["weekday"] == 4)
    data["change_7d"] = effect + rng.normal(0, noise, len(data))
    data["actual"] = data["change_7d"].map(classify)
    return data


def test_model_recovers_known_pass_through():
    model = SemaforoModel.fit(synthetic())
    coef = model.coefficients()
    assert coef["brent_7"] == pytest.approx(0.6, abs=0.05)
    assert coef["brent_14"] == pytest.approx(0.0, abs=0.05)
    assert coef["dia_vie"] == pytest.approx(0.002, abs=0.001)


def test_model_ignores_rows_without_target():
    data = synthetic()
    data.iloc[-30:, data.columns.get_loc("change_7d")] = np.nan
    SemaforoModel.fit(data)        # does not raise


def test_model_needs_some_target():
    data = synthetic().assign(change_7d=np.nan)
    with pytest.raises(ValueError):
        SemaforoModel.fit(data)


# --- backtest -------------------------------------------------------------

def test_walk_forward_never_trains_on_test_period(monkeypatch):
    seen = []
    original = SemaforoModel.fit.__func__

    def spy(cls, train):
        seen.append(train.index.max())
        return original(cls, train)

    monkeypatch.setattr(SemaforoModel, "fit", classmethod(spy))
    walk_forward(synthetic(n=1200), [2020, 2021])
    # Last training day + 7 (its target) must fall before 1 January.
    assert seen[0] + pd.Timedelta(days=7) < pd.Timestamp("2020-01-01")
    assert seen[1] + pd.Timedelta(days=7) < pd.Timestamp("2021-01-01")


def test_walk_forward_scores_each_test_year():
    results = walk_forward(synthetic(n=1200), [2020, 2021])
    assert set(results["year"]) == {2020, 2021}
    assert set(results["signal"]) <= {VERDE, AMBAR, ROJO}


def test_evaluate_beats_baseline_when_signal_is_real():
    m = evaluate(walk_forward(synthetic(n=1200), [2020, 2021]))
    assert m.skill > 0.5
    assert m.mae_model_cents < m.mae_baseline_cents
    assert m.accuracy_model > m.accuracy_baseline


def test_evaluate_baseline_accuracy_is_share_of_ambar():
    results = pd.DataFrame({
        "change_7d": [0.02, 0.0, -0.02, 0.005],
        "predicted": [0.02, 0.02, 0.0, 0.0],
    })
    results["actual"] = results["change_7d"].map(classify)
    results["signal"] = results["predicted"].map(classify)
    m = evaluate(results)
    assert m.accuracy_baseline == 0.5           # 2 of 4 actual days are ámbar
    assert m.accuracy_model == 0.5              # right on day 1 and day 4
    assert (m.verde_days, m.verde_hit_rate) == (2, 0.5)
    assert m.rojo_days == 0
    assert class_balance(results) == {VERDE: 0.25, AMBAR: 0.5, ROJO: 0.25}
