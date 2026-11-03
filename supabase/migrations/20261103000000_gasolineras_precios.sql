-- Stations and fuel price history from the Ministry's Geoportal de Gasolineras.
--
-- Storage strategy: `precios` stores one row per price CHANGE, not per snapshot.
-- A row means "from observed_at on, this station sold this fuel at this price"
-- until the next row for the same (station_id, fuel). This is lossless and
-- ~50x smaller than storing every 30-min snapshot (~43k prices each).
-- `capturas` logs every snapshot so gaps in data can be told apart from
-- "price did not change".

create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------------------
-- gasolineras: one row per station (IDEESS from the Ministry).
-- ---------------------------------------------------------------------------
create table public.gasolineras (
  id              integer primary key,                 -- IDEESS
  brand           text not null,                       -- "Rótulo"
  address         text not null,
  postal_code     text,
  locality        text,
  municipality    text,
  province        text,
  municipality_id text,
  province_id     text,
  region_id       text,                                -- IDCCAA
  opening_hours   text,
  road_side       text check (road_side in ('D', 'I', 'N')),  -- Margen: derecho / izquierdo / no aplica
  sale_type       text check (sale_type in ('P', 'R')),       -- Tipo Venta: público / restringido
  location        extensions.geography(point, 4326) not null,
  first_seen_at   timestamptz not null default now(),
  last_seen_at    timestamptz not null default now(),  -- last snapshot that listed it
  updated_at      timestamptz not null default now()
);

create index gasolineras_location_idx on public.gasolineras using gist (location);
create index gasolineras_province_idx on public.gasolineras (province_id);

-- ---------------------------------------------------------------------------
-- precios: append-only price history. Never deleted.
-- ---------------------------------------------------------------------------
create table public.precios (
  station_id  integer not null references public.gasolineras (id),
  fuel        text not null,                           -- e.g. 'gasoleo_a', 'gasolina_95_e5'
  price       numeric(6, 3) not null check (price > 0 and price < 100),  -- €/l (€/kg for gas)
  observed_at timestamptz not null,                    -- first snapshot that showed this price (±30 min)
  -- The PK index also serves "latest price per station/fuel" (backward scan).
  primary key (station_id, fuel, observed_at)
);

-- Time-series reads across all stations (e.g. national average per day).
create index precios_fuel_time_idx on public.precios (fuel, observed_at);

-- ---------------------------------------------------------------------------
-- capturas: one row per ingested snapshot (internal, not exposed to the app).
-- ---------------------------------------------------------------------------
create table public.capturas (
  id               bigint generated always as identity primary key,
  source_timestamp timestamptz not null unique,        -- "Fecha": when the Ministry generated the response
  fetched_at       timestamptz not null default now(),
  station_count    integer not null,
  price_count      integer not null,
  changed_count    integer not null
);

-- ---------------------------------------------------------------------------
-- Row Level Security: public price data is read-only for the app.
-- Writes only happen from the worker through a direct Postgres connection.
-- ---------------------------------------------------------------------------
alter table public.gasolineras enable row level security;
alter table public.precios     enable row level security;
alter table public.capturas    enable row level security;

create policy "Stations are readable by everyone"
  on public.gasolineras for select
  to anon, authenticated
  using (true);

create policy "Prices are readable by everyone"
  on public.precios for select
  to anon, authenticated
  using (true);

-- capturas: RLS on with no policies = no access through the API.

revoke insert, update, delete, truncate on public.gasolineras, public.precios from anon, authenticated;
revoke all on public.capturas from anon, authenticated;
