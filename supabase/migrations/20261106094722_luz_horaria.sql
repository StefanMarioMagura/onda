-- Hourly price of the regulated electricity tariff (PVPC), from Red Eléctrica's
-- REData API. Written by onda_workers.luz; read by the app ("Tu España").
-- REE publishes tomorrow's prices around 20:15 Madrid time.

create table public.luz_horaria (
  hour          timestamptz primary key,          -- start of the hour
  pvpc_eur_mwh  numeric(8, 2) not null check (pvpc_eur_mwh >= 0),
  updated_at    timestamptz not null default now()
);

alter table public.luz_horaria enable row level security;

create policy "Electricity prices are readable by everyone"
  on public.luz_horaria for select
  to anon, authenticated
  using (true);

revoke insert, update, delete, truncate on public.luz_horaria from anon, authenticated;
