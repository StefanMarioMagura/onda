-- News as they come, without AI (docs/decisiones/0008-noticias-sin-ia.md).
--
-- noticias: adds the outlet's name and a short extract from its feed (the full
--           article is never stored), and becomes readable by the app.
-- eventos:  each hourly run ranks the day's topics (rank is null when a topic is
--           no longer current). `headlines` keeps every outlet's real headline
--           and side, for "Las dos orillas".
-- Only additions: ondas stays, empty and unused, in case AI drafts come back.

alter table public.noticias
  add column outlet_name text,
  add column summary text check (length(summary) <= 300);

update public.noticias n set outlet_name = v.name
from (values
  ('eldiario', 'elDiario.es'), ('infolibre', 'infoLibre'), ('elpais', 'El País'),
  ('elmundo', 'El Mundo'), ('abc', 'ABC'), ('elespanol', 'El Español'),
  ('libertaddigital', 'Libertad Digital'), ('rtve', 'RTVE'), ('europapress', 'Europa Press'),
  ('20minutos', '20minutos'), ('lavanguardia', 'La Vanguardia'), ('elconfidencial', 'El Confidencial')
) as v(outlet, name)
where n.outlet = v.outlet;

alter table public.eventos
  add column key text unique,
  add column rank integer,
  add column summary text,
  add column url text,
  add column outlet_name text,
  add column headlines jsonb,
  add column updated_at timestamptz not null default now();

create index eventos_rank_idx on public.eventos (rank) where rank is not null;
create index noticias_published_idx on public.noticias (published_at desc);

-- The app reads the current topics and recent headlines, and only these columns.
grant select (key, rank, headline, summary, url, outlet_name, outlets, sides, headlines, updated_at)
  on public.eventos to anon, authenticated;
create policy "Current topics are readable by everyone"
  on public.eventos for select
  to anon, authenticated
  using (rank is not null);

grant select (id, outlet_name, title, summary, url, published_at)
  on public.noticias to anon, authenticated;
create policy "Headlines are readable by everyone"
  on public.noticias for select
  to anon, authenticated
  using (true);
