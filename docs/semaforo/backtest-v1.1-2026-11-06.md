# Semáforo · backtest

Precios nacionales del 2019-01-01 al 2026-11-04; Brent del 2018-12-03 al 2026-11-03.
Validación *walk-forward*: cada año se predice con un modelo entrenado solo con los años anteriores (2021–2026). Salvo la fila "ideal", el Brent llega con 7 días de retraso, como en la realidad.

## Gasóleo A

| Modelo | Días | Error modelo | Error referencia | Mejora | Acierto modelo | Acierto referencia | Verdes (aciertan) | Rojos (aciertan) |
|---|---|---|---|---|---|---|---|---|
| v1 · Brent + día de la semana — Brent al día (ideal) | 2121 | 1.71 c | 2.03 c | 16% | 58% | 45% | 485 (59%) | 417 (64%) |
| v1 · Brent + día de la semana | 2121 | 2.00 c | 2.03 c | 1% | 48% | 45% | 203 (46%) | 131 (45%) |
| v1.1 · Brent + tendencia + margen | 2121 | 1.76 c | 2.03 c | 13% | 58% | 45% | 350 (64%) | 263 (68%) |
| Solo surtidor · tendencia + margen | 2121 | 1.74 c | 2.03 c | 14% | 59% | 45% | 336 (66%) | 268 (67%) |

Reparto real de días: verde 28%, ámbar 45%, rojo 27%.

Por año, v1.1 · Brent + tendencia + margen:

| Año | Días | Error modelo | Error referencia | Mejora | Acierto modelo |
|---|---|---|---|---|---|
| 2021 | 365 | 0.64 c | 0.81 c | 21% | 71% |
| 2022 | 365 | 3.34 c | 4.00 c | 16% | 63% |
| 2023 | 365 | 1.36 c | 1.57 c | 13% | 43% |
| 2024 | 366 | 0.81 c | 1.02 c | 21% | 55% |
| 2025 | 359 | 0.78 c | 0.95 c | 18% | 67% |
| 2026 | 301 | 3.98 c | 4.16 c | 4% | 50% |

Coeficientes de v1.1 · Brent + tendencia + margen con todos los datos:

- `brent_7` = -0.113
- `brent_14` = -0.006
- `price_7` = +0.462
- `margin_gap` = -0.013

(Variación del precio a 7 días, en €/l, por cada €/l de la variable.)

## Gasolina 95

| Modelo | Días | Error modelo | Error referencia | Mejora | Acierto modelo | Acierto referencia | Verdes (aciertan) | Rojos (aciertan) |
|---|---|---|---|---|---|---|---|---|
| v1 · Brent + día de la semana — Brent al día (ideal) | 2121 | 1.44 c | 1.66 c | 13% | 63% | 52% | 442 (60%) | 346 (62%) |
| v1 · Brent + día de la semana | 2121 | 1.64 c | 1.66 c | 1% | 53% | 52% | 194 (38%) | 123 (43%) |
| v1.1 · Brent + tendencia + margen | 2121 | 1.39 c | 1.66 c | 17% | 66% | 52% | 319 (69%) | 257 (75%) |
| Solo surtidor · tendencia + margen | 2121 | 1.36 c | 1.66 c | 18% | 65% | 52% | 319 (67%) | 270 (73%) |

Reparto real de días: verde 26%, ámbar 52%, rojo 23%.

Por año, v1.1 · Brent + tendencia + margen:

| Año | Días | Error modelo | Error referencia | Mejora | Acierto modelo |
|---|---|---|---|---|---|
| 2021 | 365 | 0.60 c | 0.77 c | 22% | 73% |
| 2022 | 365 | 2.48 c | 3.20 c | 23% | 63% |
| 2023 | 365 | 0.95 c | 1.21 c | 22% | 51% |
| 2024 | 366 | 0.66 c | 0.85 c | 23% | 70% |
| 2025 | 359 | 0.60 c | 0.71 c | 16% | 78% |
| 2026 | 301 | 3.36 c | 3.55 c | 5% | 58% |

Coeficientes de v1.1 · Brent + tendencia + margen con todos los datos:

- `brent_7` = -0.039
- `brent_14` = -0.064
- `price_7` = +0.365
- `margin_gap` = +0.030

(Variación del precio a 7 días, en €/l, por cada €/l de la variable.)

*Error* = error absoluto medio del cambio de precio a 7 días. *Mejora* = 1 − error modelo / error referencia. La referencia es "mañana igual que hoy": cambio 0, siempre ámbar.

