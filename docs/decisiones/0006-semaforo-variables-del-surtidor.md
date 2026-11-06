# 0006 · Semáforo: variables del surtidor en lugar del Brent con retraso

**Fecha:** 2026-11-06 · **Estado:** propuesta (pendiente de aprobar el cambio en CLAUDE.md)

Informe: [docs/semaforo/backtest-v1.1-2026-11-06.md](../semaforo/backtest-v1.1-2026-11-06.md).
Contexto: el ADR 0005 mostró que el v1 no sirve con el Brent real de la EIA (7 días de retraso).

## Qué se probó
Dos variables que se conocen el mismo día, sin retraso:
- `price_7`: cuánto ha cambiado el precio en surtidor en los últimos 7 días.
- `margin_gap`: el margen de hoy (precio menos Brent conocido) frente a su media de 90 días.

Tres variantes, evaluadas en los mismos ~2.100 días por carburante (2021–2026), todas con el
Brent que tendríamos de verdad:

| Modelo | Gasóleo A: mejora / acierto | Gasolina 95: mejora / acierto |
|---|---|---|
| v1 (Brent + día de la semana) | 1 % / 48 % | 1 % / 53 % |
| v1.1 (Brent + tendencia + margen) | 13 % / 58 % | 17 % / 66 % |
| **Solo surtidor (tendencia + margen)** | **14 % / 59 %** | **18 % / 65 %** |
| *Referencia: v1 con Brent al día (imposible en la realidad)* | *16 % / 58 %* | *13 % / 63 %* |

Cuando el modelo "solo surtidor" dice verde o rojo, acierta entre el 66 % y el 73 % de las veces
(la referencia nunca da verde ni rojo). La mejora es positiva todos los años, aunque en 2026 baja
al 4–5 %.

## Qué significa
- **Casi toda la señal está en la tendencia del propio precio** (`price_7`, coeficiente ≈ +0,4):
  si el precio ha subido esta semana, suele seguir subiendo la siguiente. Encaja con que las
  gasolineras trasladan los cambios del crudo poco a poco.
- **El margen apenas aporta** y su signo cambia según el carburante: no se puede defender como
  efecto real con estos datos.
- **El Brent con retraso no añade nada** cuando ya está la tendencia del precio: v1.1 ≈ solo surtidor.

## Propuesta
- Sustituir el modelo v1 de CLAUDE.md por el **v2 "solo surtidor"**: regresión del cambio a 7 días
  sobre `price_7` y `margin_gap`, mismos umbrales (±1 cént.) y misma comparación con la referencia.
- Siguiente simplificación a probar: solo `price_7`. Si rinde igual, es el modelo más fácil de
  explicar en la memoria.
- El Brent sigue siendo útil para el contenido de las ondas ("el petróleo sube un 6 %") y para un
  futuro modelo si aparece una fuente diaria con licencia.
