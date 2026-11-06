"""Shared fixtures for the database integration tests.

They need a disposable Postgres + PostGIS (the schema is dropped and rebuilt
for every test) and are skipped unless TEST_DATABASE_URL is set:

    docker run --rm -d -p 54329:5432 -e POSTGRES_PASSWORD=test postgis/postgis:17-3.5
    TEST_DATABASE_URL=postgresql://postgres:test@localhost:54329/postgres pytest
"""

import os
from pathlib import Path

import pytest

DB_URL = os.environ.get("TEST_DATABASE_URL")
requires_db = pytest.mark.skipif(not DB_URL, reason="TEST_DATABASE_URL not set")

ROOT = Path(__file__).resolve().parents[2]

# Migrations that only make sense on Supabase (they need pg_cron, pg_net and
# Vault) and that the worker code does not depend on.
SUPABASE_ONLY = {"dispatch_price_ingestion"}

MIGRATIONS = [
    m for m in sorted((ROOT / "supabase" / "migrations").glob("*.sql"))
    if m.stem.split("_", 1)[1] not in SUPABASE_ONLY
]

TABLES = "public.precios, public.gasolineras, public.capturas, public.precios_diarios, public.brent_diario, public.semaforo_diario"

# Minimal stand-ins for what Supabase provides, so the migrations run on vanilla Postgres.
# The postgis/postgis image pre-installs PostGIS in `public`; Supabase uses `extensions`.
SUPABASE_SHIM = """
drop extension if exists postgis_tiger_geocoder, postgis_topology, postgis cascade;
create schema if not exists extensions;
do $$ begin
  if not exists (select from pg_roles where rolname = 'anon') then create role anon; end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
end $$;
"""


@pytest.fixture
def conn():
    psycopg = pytest.importorskip("psycopg")
    with psycopg.connect(DB_URL, autocommit=True) as c:
        c.execute(f"drop table if exists {TABLES} cascade")
        c.execute(SUPABASE_SHIM)
        for migration in MIGRATIONS:
            c.execute(migration.read_text())
        c.autocommit = False
        yield c
