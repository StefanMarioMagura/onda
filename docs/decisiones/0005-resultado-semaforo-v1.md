# 0005 · Semáforo v1: resultado del backtest

**Fecha:** 2026-11-05 · **Estado:** aceptada (el v1 no se publica tal cual)

Informe completo: [docs/semaforo/backtest-v1-2026-11-05.md](../semaforo/backtest-v1-2026-11-05.md).
Se repite con el workflow manual `semaforo-backtest`.

## Qué se probó
El modelo de CLAUDE.md: regresión del cambio del precio medio nacional a 7 días sobre los
cambios del Brent en euros de los últimos 14 días (dos ventanas de 7) y el día de la semana.
Validación *walk-forward* por años (2021–2026, ~2.100 días por carburante), comparando con la
referencia "mañana igual que hoy" (cambio 0, siempre ámbar). Dos escenarios: Brent conocido el
mismo día (ideal) y con los 7 días de retraso con que publica la EIA (real).

## Resultado
| Gasóleo A | Error medio | Mejora vs. referencia | Acierto del color |
|---|---|---|---|
| Referencia | 2,02 cént. | – | 45 % |
| Modelo, Brent al día | 1,70 cént. | **16 %** | **58 %** |
| Modelo, Brent con retraso real | 2,00 cént. | 1 % | 48 % |

La gasolina 95 da lo mismo: 14 % de mejora con el Brent al día y 1 % con el retraso real.

1. **La idea funciona:** con el Brent del día, el modelo supera a la referencia y, cuando dice
   verde o rojo, acierta alrededor del 60 % de las veces.
2. **El retraso de la EIA la anula:** con el dato que tendríamos de verdad, la mejora es del 1 %
   y verdes y rojos aciertan menos de la mitad. Publicado así, el semáforo engañaría.
3. **El día de la semana no aporta nada** a este horizonte: el precio de dentro de 7 días cae en el
   mismo día de la semana que hoy, así que el ciclo semanal se anula. Sobra como variable.
4. Los años de mucha volatilidad (2022 y 2026) son los peores: errores de 3–4 céntimos.

## Decisión
- El semáforo **no se publica con el Brent de la EIA**.
- Siguiente paso, por orden:
  1. Probar variables que se conocen al día sin retraso: la tendencia del propio precio en
     surtidor (últimos 7 días) y la distancia entre el precio y lo que "debería" costar según el
     Brent (los márgenes tienden a volver a su media).
  2. Buscar una fuente diaria del Brent (futuros) con licencia que permita usarla.
- Mantener siempre la comparación con la referencia: si un modelo no la supera, no se publica.
