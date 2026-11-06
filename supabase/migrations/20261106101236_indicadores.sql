-- Official statistics shown in "Tu España" (INE for now), one row per series
-- and period. Written by onda_workers.ine; read by the app.
--
-- periodo is the first day of the period: the month for monthly series
-- (CPI), 1 January for annual ones (salaries).

create table public.indicadores (
  serie        text not null,                  -- ONDA name, e.g. 'ipc_alimentos_anual'
  periodo      date not null,
  valor        numeric(14, 4) not null,
  fuente       text not null,                  -- source series code, e.g. 'INE:IPC290754'
  updated_at   timestamptz not null default now(),
  primary key (serie, periodo)
);

alter table public.indicadores enable row level security;

create policy "Indicators are readable by everyone"
  on public.indicadores for select
  to anon, authenticated
  using (true);

revoke insert, update, delete, truncate on public.indicadores from anon, authenticated;
