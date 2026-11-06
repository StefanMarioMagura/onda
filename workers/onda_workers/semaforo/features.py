"""Dataset for the semáforo v1: features, target and traffic-light classes.

For each decision day t (one row per calendar day):
- target  `change_7d`: national average price on t+7 minus on t (€/l).
- features `brent_7` and `brent_14`: change of Brent in €/litre over the last
  7 days and over the 7 days before that (together, the last 14 days),
  computed only from Brent values *known* on day t. The EIA publishes with
  about a week of delay, so with `brent_lag_days=7` the latest Brent usable
  on day t is the one from t-7.
- `weekday`: 0 = Monday ... 6 = Sunday.
- `price_7` (v1.1): change of the pump price over the last 7 days. Known on
  day t with no delay, unlike Brent.
- `margin_gap` (v1.1): today's margin (pump price minus Brent known on t, both
  in €/l) minus its average over the last 90 days. Margins tend to return to
  normal, so a high margin suggests prices will fall and a low one, rise.

Brent in €/barrel is converted to €/litre (÷ 158.987) so the model's
coefficients read directly as "cents at the pump per cent of crude".
"""

from __future__ import annotations

import pandas as pd

LITRES_PER_BARREL = 158.987
HORIZON_DAYS = 7
WINDOW_DAYS = 7
# Verde if the price is expected to rise more than 1 cent/l, rojo if it is
# expected to fall more than 1 cent/l, ámbar otherwise.
THRESHOLD_EUR = 0.01

VERDE, AMBAR, ROJO = "verde", "ambar", "rojo"
BRENT_FEATURES = ["brent_7", "brent_14"]
PUMP_FEATURES = ["price_7", "margin_gap"]
ALL_FEATURES = BRENT_FEATURES + PUMP_FEATURES
MARGIN_WINDOW_DAYS = 90
# The EIA publishes Brent about a week late: training and live use the same lag.
BRENT_LAG_DAYS = 7


def classify(change_eur: float) -> str:
    """Traffic light for an expected 7-day price change (€/l).

    Verde = fill up today (prices will rise); rojo = wait (they will fall).
    Exactly ±1 cent is still ámbar.
    """
    if change_eur > THRESHOLD_EUR:
        return VERDE
    if change_eur < -THRESHOLD_EUR:
        return ROJO
    return AMBAR


def to_daily(series: pd.Series, fill: bool) -> pd.Series:
    """Reindex to every calendar day between the first and last date.

    fill=True carries the last value forward (Brent on weekends and holidays:
    the latest known quote still applies). fill=False leaves gaps as NaN
    (missing price days must not invent a target).
    """
    series = series.sort_index()
    series.index = pd.DatetimeIndex(series.index)
    days = pd.date_range(series.index.min(), series.index.max(), freq="D")
    daily = series.reindex(days)
    return daily.ffill() if fill else daily


def build_dataset(prices: pd.Series, brent_eur_bbl: pd.Series, brent_lag_days: int) -> pd.DataFrame:
    """One row per day with features, target and actual class.

    prices: national average price (€/l) indexed by day.
    brent_eur_bbl: Brent in €/barrel indexed by trading day.
    Rows whose target is unknown (the last 7 days, or price gaps) keep
    `change_7d` = NaN: they are the days the model predicts but cannot score.
    """
    price = to_daily(prices.astype(float), fill=False)
    brent = to_daily(brent_eur_bbl.astype(float) / LITRES_PER_BARREL, fill=True)
    brent = brent.reindex(price.index.union(brent.index)).ffill()

    known = brent.shift(brent_lag_days)          # latest Brent available on day t
    data = pd.DataFrame(index=price.index)
    data["price"] = price
    data["brent_7"] = (known - known.shift(WINDOW_DAYS)).reindex(price.index)
    data["brent_14"] = (known.shift(WINDOW_DAYS) - known.shift(2 * WINDOW_DAYS)).reindex(price.index)
    data["weekday"] = data.index.day_of_week
    data["price_7"] = price - price.shift(WINDOW_DAYS)
    margin = price - known.reindex(price.index)
    data["margin_gap"] = margin - margin.rolling(MARGIN_WINDOW_DAYS, min_periods=60).mean()
    data["change_7d"] = price.shift(-HORIZON_DAYS) - price
    data["actual"] = data["change_7d"].map(classify, na_action="ignore")
    # Pump features may still be NaN (gaps, warm-up): each model variant drops
    # the rows it cannot use.
    return data.dropna(subset=["price", *BRENT_FEATURES])
