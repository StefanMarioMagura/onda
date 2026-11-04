# 0002 · Disparo de la ingesta: pg_cron en lugar del cron de GitHub

**Fecha:** 2026-11-04 · **Estado:** aceptada

## Contexto
La ingesta de precios (ADR 0001) debe ejecutarse cada 30 min. El evento `schedule`
de GitHub Actions no lo garantiza: en sus primeras 11 h este repositorio
recibió 2 de las ~22 ejecuciones previstas. Cada ejecución perdida es un hueco en el
histórico que no se puede recuperar, porque la API del Ministerio solo da el precio actual.

## Decisión
- `pg_cron` en Supabase ejecuta `internal.dispatch_price_ingestion()` a las :02 y :32.
- La función llama con `pg_net` a la API de GitHub (`workflow_dispatch`) y lanza el
  workflow `ingest-prices`. El worker sigue en Python y en GitHub Actions.
- El token de GitHub vive en Supabase Vault (`github_actions_token`): un token
  *fine-grained* limitado a este repositorio con permiso solo de Actions (lectura y escritura).
- El `schedule` de GitHub (:07/:37) se mantiene como respaldo. Si se ejecutan los dos,
  no pasa nada: la ingesta es idempotente.
- La función vive en el esquema `internal`, que no se expone en la API de datos.

## Consecuencias
- El token caduca: hay que renovarlo en GitHub y actualizarlo en Vault antes de la fecha
  de caducidad, o la ingesta vuelve a depender solo del cron de GitHub.
- Para revisar el disparo:
  - `cron.job_run_details`: si la función se ejecutó (falla si falta el secreto).
  - `net._http_response`: respuesta de GitHub (204 = workflow lanzado). Se guarda 6 h.
  - `capturas`: si la ingesta llegó a guardar el snapshot.

## Alternativas descartadas
- **Servicio de cron externo** (cron-job.org…): una cuenta y una dependencia más fuera del stack.
- **Reescribir la ingesta como Edge Function:** perdería el worker en Python, sus tests y
  la transacción única con psycopg.
