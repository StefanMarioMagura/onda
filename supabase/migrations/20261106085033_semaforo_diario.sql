-- Daily semáforo forecast ("¿lleno hoy o espero?"), written by the
-- onda_workers.semaforo.daily worker and read by the app.
--
-- One row per (day, province, fuel). `day` is the last day with known prices
-- (the Ministry's daily data arrives the next morning), and the forecast is
-- the expected change from that day to 7 days later. For now only the
-- national series (province_id '00') is forecast: the model was validated on
-- it (docs/decisiones/0006).

create table public.semaforo_diario (
  day              date not null,
  province_id      text not null default '00',
  fuel             text not null,
  model            text not null,                    -- e.g. 'v2'
  price            numeric(6, 3) not null,           -- national average on `day`, €/l
  expected_change  numeric(7, 4) not null,           -- €/l over the next 7 days
  signal           text not null check (signal in ('verde', 'ambar', 'rojo')),
  price_7          numeric(7, 4) not null,           -- inputs, to explain the forecast
  margin_gap       numeric(7, 4) not null,
  trained_until    date not null,                    -- last day with a known 7-day outcome
  created_at       timestamptz not null default now(),
  primary key (day, province_id, fuel)
);

alter table public.semaforo_diario enable row level security;

create policy "Semáforo is readable by everyone"
  on public.semaforo_diario for select
  to anon, authenticated
  using (true);

revoke insert, update, delete, truncate on public.semaforo_diario from anon, authenticated;
