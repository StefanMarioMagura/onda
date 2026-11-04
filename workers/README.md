# ONDA workers

## Ingesta de precios (`onda_workers.ingest_prices`)
Descarga el snapshot del Ministerio y guarda en Supabase las estaciones y los precios que
han cambiado. Lo ejecuta el GitHub Action `ingest-prices` cada 30 min, que lanza pg_cron desde
Supabase ([ADR 0002](../docs/decisiones/0002-disparo-de-la-ingesta.md)).
Diseño: [docs/decisiones/0001-historico-de-precios.md](../docs/decisiones/0001-historico-de-precios.md).

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

### Secreto en Supabase Vault
- `github_actions_token`: token *fine-grained* de GitHub (solo este repositorio,
  permiso **Actions: Read and write**). Lo usa pg_cron para lanzar `ingest-prices`.
  Se crea o renueva en el SQL Editor de Supabase:
  ```sql
  select vault.create_secret('<token>', 'github_actions_token');            -- crear
  select vault.update_secret(id, '<token>') from vault.secrets
    where name = 'github_actions_token';                                    -- renovar
  ```
