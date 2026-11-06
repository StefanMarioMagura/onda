# ONDA workers

## Ingesta de precios (`onda_workers.ingest_prices`)
Descarga el snapshot del Ministerio y guarda en Supabase las estaciones y los precios que
han cambiado. Lo ejecuta el GitHub Action `ingest-prices` cada 30 min, que lanza pg_cron desde
Supabase ([ADR 0002](../docs/decisiones/0002-disparo-de-la-ingesta.md)).
Diseño: [docs/decisiones/0001-historico-de-precios.md](../docs/decisiones/0001-historico-de-precios.md).

## Histórico diario por provincia (`onda_workers.daily_history`)
Descarga del endpoint histórico del Ministerio los precios de cada día desde 2019 y guarda en
`precios_diarios` media, mediana, mínimo, máximo y nº de estaciones por provincia y carburante
(`'00'` = España). Rellena solo los días que faltan. Lo ejecuta el GitHub Action
`ingest-daily-history` una vez al día ([ADR 0003](../docs/decisiones/0003-historico-diario-por-provincia.md)).

```bash
# Probar sin base de datos
.venv/bin/python -m onda_workers.daily_history --dry-run --since 2025-11-03 --until 2025-11-03
# Carga inicial en tandas (cada tanda continúa donde lo dejó la anterior)
gh workflow run ingest-daily-history.yml
```

## Brent y EUR/USD (`onda_workers.brent`)
Brent diario de la EIA (serie `RBRTE`, $/barril) convertido a euros con el cambio de referencia
del BCE. Guarda en `brent_diario`; relee los últimos 30 días en cada ejecución. Lo ejecuta el
GitHub Action `ingest-brent` a diario ([ADR 0004](../docs/decisiones/0004-brent-y-cambio.md)).
La EIA publica una vez por semana: el último dato suele tener entre 5 y 9 días.

```bash
EIA_API_KEY=... .venv/bin/python -m onda_workers.brent --dry-run --since 2025-12-01
```

## Semáforo (`onda_workers.semaforo`)
- `daily`: entrena el modelo actual (v2) con todo el histórico y guarda en `semaforo_diario` la
  previsión a 7 días desde el último día con precios. Si ese día tiene más de 3 días, no publica.
  Lo lanza el workflow `semaforo-daily` justo después de cargar los precios diarios.
- `backtest`: informe *walk-forward* de todas las variantes. Workflow manual `semaforo-backtest`.

## Desarrollo

```bash
cd workers
python -m venv .venv && .venv/bin/pip install -e '.[dev]'

# Tests del parser (sin base de datos)
.venv/bin/pytest

# Tests de integración con PostGIS desechable
docker run --rm -d --name onda-test-pg -p 54329:5432 -e POSTGRES_PASSWORD=test postgis/postgis:17-3.5
TEST_DATABASE_URL=postgresql://postgres:test@localhost:54329/postgres .venv/bin/pytest

# Ejecutar contra Supabase (cadena del pooler, modo session)
DATABASE_URL='postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres' \
  .venv/bin/python -m onda_workers.ingest_prices
```

### Secretos de GitHub
- `SUPABASE_DB_URL`: cadena de conexión del **pooler** (Project Settings → Database →
  Connection string → Session pooler). Los runners de GitHub no tienen IPv6, así que el host
  directo `db.<ref>.supabase.co` no funciona.
- `EIA_API_KEY`: clave gratuita de la API de la EIA (https://www.eia.gov/opendata/register.php).

### Secreto en Supabase Vault
- `github_actions_token`: token *fine-grained* de GitHub (solo este repositorio,
  permiso **Actions: Read and write**). Lo usa pg_cron para lanzar `ingest-prices`.
  Se crea o renueva en el SQL Editor de Supabase:
  ```sql
  select vault.create_secret('<token>', 'github_actions_token');            -- crear
  select vault.update_secret(id, '<token>') from vault.secrets
    where name = 'github_actions_token';                                    -- renovar
  ```
