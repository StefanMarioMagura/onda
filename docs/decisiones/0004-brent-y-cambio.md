# 0004 · Brent en euros: EIA + tipo de cambio del BCE

**Fecha:** 2026-11-04 · **Estado:** aceptada

## Contexto
El semáforo v1 usa como variable principal los cambios del Brent en euros de los
últimos 14 días. Hace falta el Brent diario en dólares y el cambio EUR/USD, con
histórico desde antes de 2019 (inicio de `precios_diarios`).

## Decisión
- **Brent:** API v2 de la EIA, serie `RBRTE` (Europe Brent Spot Price FOB, $/barril).
  La clave (`EIA_API_KEY`, gratuita) va en la cabecera `X-Api-Key`, no en la URL, para
  que no aparezca en mensajes de error ni en logs.
- **Cambio:** API del BCE, serie `EXR.D.USD.EUR.SP00.A` (dólares por euro, fixing de
  las 14:15). No necesita clave.
- **Tabla `brent_diario`:** una fila por día de cotización del Brent, con `brent_usd`,
  `usd_per_eur`, `fx_day` y `brent_eur`, una columna generada en la base de datos para
  que la fórmula esté en un solo sitio.
- **Calendarios distintos:** el Brent no cotiza en festivos de Reino Unido y EE. UU.; el BCE
  no publica en festivos TARGET. Cada día de Brent usa el último cambio del BCE de ese día
  o anterior (nunca uno posterior, que sería información del futuro). `fx_day` indica cuál.
  Si el último cambio tiene más de 7 días, el día se descarta.
- **Actualización:** el GitHub Action `ingest-brent` se ejecuta a diario, relee los últimos
  30 días y hace *upsert*. La primera ejecución carga desde 2018-12-01 (~2.000 días).

## Consecuencias
- **Retraso del Brent:** la EIA publica una vez por semana. El 2026-11-04 el último dato era
  del 2026-10-27, 8 días antes. Para entrenar no importa, pero en producción el semáforo
  tendría solo la mitad de su ventana de 14 días. Hay que resolverlo antes de publicar
  el semáforo: con una fuente diaria (futuros del Brent) o con un modelo que use solo
  los datos disponibles a cada fecha. Para que la evaluación sea honesta, el backtest
  debe simular este retraso.
- Las revisiones de la EIA se recogen solas en los 30 días que se releen.

## Alternativas descartadas
- **FRED (`DCOILBRENTEU`):** permite descargar CSV sin clave, pero son los mismos datos de la
  EIA con el mismo retraso. CLAUDE.md ya fija la EIA como fuente.
- **Cambio del mismo día o interpolado:** el del mismo día no existe en festivos del BCE, e
  interpolar usaría el cambio del día siguiente (fuga de información del futuro).
