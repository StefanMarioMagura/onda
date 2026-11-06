-- Ondas engine (docs/decisiones/0007-motor-de-ondas.md).
--
-- noticias: headline + link from outlet RSS feeds. Never the outlet's text.
-- eventos:  headlines grouped into one story, the input for a draft onda.
-- ondas:    drafts written by Claude; a person approves or discards them.
-- The app can read only published ondas, and only their public columns.

create table public.noticias (
  id            bigint generated always as identity primary key,
  outlet        text not null,                               -- id in onda_workers.news.sources
  title         text not null check (length(title) between 5 and 400),
  url           text not null unique,
  published_at  timestamptz,
  fetched_at    timestamptz not null default now()
);
create index noticias_fetched_idx on public.noticias (fetched_at desc);

create table public.eventos (
  id           bigint generated always as identity primary key,
  created_at   timestamptz not null default now(),
  headline     text not null,                                -- most representative headline
  noticia_ids  bigint[] not null,
  outlets      integer not null check (outlets > 0),
  sides        text[] not null                               -- orillas covered: izquierda / centro / derecha
);

create table public.ondas (
  id             bigint generated always as identity primary key,
  evento_id      bigint references public.eventos (id),
  estado         text not null default 'borrador' check (estado in ('borrador', 'publicada', 'descartada')),
  capa           text not null check (capa in ('bolsillo', 'pais', 'mundo')),
  contenido      jsonb not null,                             -- cards, shores, stance, sources (shown in the app)
  verificar      jsonb not null,                             -- claims + source links, for the reviewer only
  modelo         text not null,
  creada_en      timestamptz not null default now(),
  revisada_en    timestamptz,
  publicada_para date,                                       -- day it appears in the feed
  nota_revision  text,
  check ((estado = 'publicada') = (publicada_para is not null))
);
create index ondas_publicadas_idx on public.ondas (publicada_para) where estado = 'publicada';

alter table public.noticias enable row level security;
alter table public.eventos  enable row level security;
alter table public.ondas    enable row level security;

-- noticias / eventos: internal, no policies = no API access.
revoke all on public.noticias, public.eventos from anon, authenticated;

-- ondas: published rows only, and only the columns the app shows.
revoke all on public.ondas from anon, authenticated;
grant select (id, capa, contenido, publicada_para) on public.ondas to anon, authenticated;

create policy "Published ondas are readable by everyone"
  on public.ondas for select
  to anon, authenticated
  using (estado = 'publicada');
