-- Daily fuel price statistics per province, backfilled from the Ministry's
-- historical endpoint (EstacionesTerrestresHist/{dd-mm-yyyy}, data since 2007).
--
-- Per-station daily history does not fit the free plan (~430 MB/year), and
-- the semáforo v1 model works on aggregate prices, so we keep one row per
-- (day, province, fuel) with summary statistics: ~8 MB/year for 4 fuels.
-- See docs/decisiones/0003-historico-diario-por-provincia.md.

create table public.precios_diarios (
  day           date not null,                       -- day the Ministry's prices apply to
  province_id   text not null,                       -- IDProvincia ('01'..'52'); '00' = all of Spain
  fuel          text not null,                       -- same codes as precios.fuel
  avg_price     numeric(7, 4) not null,              -- €/l, plain mean over stations
  median_price  numeric(6, 3) not null,
  min_price     numeric(6, 3) not null,
  max_price     numeric(6, 3) not null,
  station_count integer not null check (station_count > 0),
  primary key (day, province_id, fuel)
);

-- Time series for one fuel and province (what the model and charts read).
create index precios_diarios_series_idx on public.precios_diarios (fuel, province_id, day);

alter table public.precios_diarios enable row level security;

create policy "Daily prices are readable by everyone"
  on public.precios_diarios for select
  to anon, authenticated
  using (true);

revoke insert, update, delete, truncate on public.precios_diarios from anon, authenticated;
