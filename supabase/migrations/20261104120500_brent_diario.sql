-- Daily Brent crude price in dollars and euros: the semáforo's main input.
--
-- Brent: EIA spot price FOB (series RBRTE), $/barrel, one row per EIA trading day.
-- Exchange rate: ECB reference rate (USD per EUR, 14:15 CET). Its calendar
-- differs from Brent's (TARGET vs UK/US holidays), so each Brent day uses the
-- latest ECB rate on or before that day; fx_day records which one.
-- See docs/decisiones/0004-brent-y-cambio.md.

create table public.brent_diario (
  day          date primary key,                     -- EIA trading day
  brent_usd    numeric(8, 3) not null check (brent_usd > 0),
  usd_per_eur  numeric(8, 5) not null check (usd_per_eur > 0),
  fx_day       date not null check (fx_day <= day),  -- ECB day the rate comes from
  brent_eur    numeric(8, 3) generated always as (round(brent_usd / usd_per_eur, 3)) stored,
  updated_at   timestamptz not null default now()
);

alter table public.brent_diario enable row level security;

create policy "Brent prices are readable by everyone"
  on public.brent_diario for select
  to anon, authenticated
  using (true);

revoke insert, update, delete, truncate on public.brent_diario from anon, authenticated;
