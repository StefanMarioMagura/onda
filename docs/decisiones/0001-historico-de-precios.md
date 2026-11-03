# 0001 · Histórico de precios: guardar solo los cambios

**Fecha:** 2026-11-03 · **Estado:** aceptada

## Contexto
La API del Ministerio (Geoportal de Gasolineras) devuelve cada vez todas las
estaciones (~11.450) con todos sus precios (~43.000). Se actualiza cada media hora.
Necesitamos el histórico completo desde ya para entrenar el semáforo.

Guardar cada snapshot entero supondría ~2 M filas/día (~750 M/año), mucho más de
lo que cabe en el plan gratuito de Supabase.

## Decisión
- `precios` guarda **una fila por cambio de precio**: `(station_id, fuel, price, observed_at)`.
  El precio es válido desde `observed_at` hasta la siguiente fila de la misma
  estación y carburante. No se pierde información y la tabla nunca se borra.
- `capturas` registra cada snapshot procesado (hora, nº de estaciones, precios y cambios).
  Así se distingue "el precio no cambió" de "ese día no tenemos datos".
- `observed_at` es la hora del primer snapshot en el que vimos el precio. El campo
  `Fecha` de la API es la hora de generación de la respuesta, no la del cambio real,
  así que la precisión es de ±30 min, suficiente para un modelo con horizonte de 7 días.
- La ingesta se ejecuta en una sola transacción y es idempotente: repetirla no duplica datos.

## Consecuencias
- Para obtener "el precio a una hora T" hay que buscar la última fila con `observed_at <= T`
  (lo resuelve la clave primaria).
- Si una estación deja de vender un carburante, el último precio queda "vigente" en el histórico.
  Se podrá cruzar con `capturas` y `gasolineras.last_seen_at` si hace falta.
- Se descartan las estaciones con coordenadas inválidas (0,0 o fuera de España).
  En el snapshot del 2026-11-03 fueron 5 de 11.458.

## Alternativas descartadas
- **Snapshot completo cada 30 min:** demasiado volumen para el valor que aporta.
- **Un snapshot al día:** pierde las subidas y bajadas dentro del día, que son justo lo que
  necesita "¿lleno hoy o espero?".
