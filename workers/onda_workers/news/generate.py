"""Turn the day's biggest news events into DRAFT ondas with Claude.

Reads the last 24 h of headlines, groups them into events, and for the best
covered ones asks Claude for an onda in a fixed JSON schema. Drafts are saved
with estado 'borrador': nothing is published until a person approves it
(onda_workers.news.review). See docs/decisiones/0007-motor-de-ondas.md.

Usage:
    ANTHROPIC_API_KEY=... DATABASE_URL=postgresql://... python -m onda_workers.news.generate
    DATABASE_URL=... python -m onda_workers.news.generate --dry-run     # list events, no Claude calls
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from datetime import date, datetime
from typing import Any, Literal

import anthropic
import psycopg
from pydantic import BaseModel

from ..ministerio import MADRID
from .cluster import Event, Item, cluster
from .sources import BY_ID

log = logging.getLogger("onda_workers.news.generate")

MODEL = "claude-opus-5-5"
# Server-side fallback: if the model declines a request, the API re-runs it on
# Anthropic's recommended fallback model inside the same call.
FALLBACK_BETA = "server-side-fallback-2026-07-01"
MAX_DRAFTS = 6
MAX_CANDIDATES = 10


# --------------------------------------------------------------------------
# Output schema (validated by the SDK, then checked again by check_draft)
# --------------------------------------------------------------------------

class Figure(BaseModel):
    value: str
    caption: str


class Card(BaseModel):
    headline: str
    body: str
    figure: Figure | None
    teaser: str | None
    actions: list[str]


class Shores(BaseModel):
    supporters: str
    critics: str
    shared_facts: list[str]


class StanceOut(BaseModel):
    economia: int
    sociedad: int
    territorio: int


class Claim(BaseModel):
    claim: str
    source_url: str


class WaveDraft(BaseModel):
    relevant: bool
    relevance_reason: str
    layer: Literal["bolsillo", "pais", "mundo"]
    cards: list[Card]
    shores: Shores | None
    stance: StanceOut | None
    claims: list[Claim]


SYSTEM_PROMPT = """\
Eres la redacción de ONDA, una app que explica a adultos que viven en España lo que pasa en el mundo \
por lo que les cuesta o les cambia en su vida. Recibes los titulares de varios medios sobre un mismo \
suceso, cada uno con su medio, su orilla editorial (izquierda, centro o derecha) y su enlace. Con eso \
escribes una "onda": cuatro tarjetas breves en español de España.

Lo más importante: usa solo lo que dicen los titulares. No añadas cifras, fechas, nombres, citas ni \
causas que no aparezcan en ellos, aunque las conozcas. Si para explicar las consecuencias haría falta \
información que los titulares no dan, dilo con prudencia ("aún no se sabe...") en lugar de suponer. \
Cada afirmación de hecho de las tarjetas va en `claims` con el enlace del titular que la respalda; \
solo puedes usar enlaces de la lista recibida. Una persona revisará la onda antes de publicarla.

Decide primero si merece una onda (`relevant`): sí cuando afecta a la vida, el dinero, los derechos o \
los servicios de la gente en España; no para deportes, cultura y espectáculos, famosos, o sucesos \
sin consecuencias para el público. Si no es relevante, rellena el resto de forma mínima.

Capa: `bolsillo` (precios, impuestos, salarios, vivienda, energía), `pais` (política y decisiones \
públicas en España), `mundo` (sucesos de fuera con efecto en España).

Las cuatro tarjetas, en este orden: 1) qué pasó, 2) por qué importa, 3) cómo te llega, 4) qué puedes \
hacer. Titular de cada tarjeta de 90 caracteres como mucho; cuerpo de 280 como mucho. Tono claro y \
sereno, sin sensacionalismo ni opinión. No copies titulares: redacta con tus palabras. `figure` solo \
si hay una cifra clara en los titulares (si no, null). En las tarjetas 1 a 3, `teaser` es la pregunta \
que responde la tarjeta siguiente, y `actions` va vacío; en la 4, `teaser` es null y `actions` tiene \
2 o 3 acciones concretas y honestas (si no hay nada que hacer, cómo seguir el tema).

"Las dos orillas" (`shores`): solo en la capa `pais` y solo si hay titulares de la izquierda y de la \
derecha. Describe cómo enfoca el tema cada lado según sus titulares, sin juzgar quién tiene razón, y \
en `shared_facts` los hechos en los que coinciden ambos lados. Si no se cumple, null.

Marca para el mapa político (`stance`): solo si la noticia trata una medida o propuesta política \
concreta. Para cada eje, 1 si estar a favor de la medida empuja hacia el extremo alto, -1 hacia el \
bajo, 0 si no aplica. Economía: alto = derecha (menos impuestos y gasto, más mercado), bajo = \
izquierda. Sociedad: alto = conservador, bajo = progresista. Territorio: alto = más centralismo, \
bajo = más autogobierno. Si no es una medida política, null.
"""


def build_user_message(event: Event, today: date) -> str:
    lines = [f"Fecha: {today.isoformat()}", "", "Titulares sobre el suceso:"]
    for item in sorted(event.items, key=lambda i: i.outlet):
        outlet = BY_ID[item.outlet]
        lines.append(f"- [{outlet.name} · {outlet.side}] {item.title} — {item.url}")
    return "\n".join(lines)


class DraftRefused(RuntimeError):
    """Claude (and its fallback) declined, or the output was cut off."""


def write_draft(client: anthropic.Anthropic, event: Event, today: date) -> WaveDraft:
    """One Claude call: the event's headlines in, a validated WaveDraft out."""
    response = client.beta.messages.parse(
        model=MODEL,
        max_tokens=16000,
        betas=[FALLBACK_BETA],
        fallbacks="default",
        output_config={"effort": "high"},
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": build_user_message(event, today)}],
        output_format=WaveDraft,
    )
    if response.stop_reason == "refusal":
        raise DraftRefused("Declined by the model and its fallback")
    if response.stop_reason == "max_tokens" or response.parsed_output is None:
        raise DraftRefused(f"No complete output (stop_reason={response.stop_reason})")
    return response.parsed_output


# --------------------------------------------------------------------------
# Checks (pure): what the schema can't enforce
# --------------------------------------------------------------------------

def check_draft(draft: WaveDraft, event: Event) -> list[str]:
    """Problems that make a draft unusable. Empty list = OK to save for review."""
    problems = []
    if len(draft.cards) != 4:
        problems.append(f"{len(draft.cards)} cards instead of 4")
    else:
        if any(c.actions for c in draft.cards[:3]) or not draft.cards[3].actions:
            problems.append("actions must appear only on card 4")
        if draft.cards[3].teaser:
            problems.append("card 4 must not have a teaser")
    for i, card in enumerate(draft.cards, 1):
        if len(card.headline) > 110 or len(card.body) > 340:
            problems.append(f"card {i} too long")
    urls = {item.url for item in event.items}
    if not draft.claims:
        problems.append("no claims to verify")
    for claim in draft.claims:
        if claim.source_url not in urls:
            problems.append(f"claim cites a link that was not given: {claim.source_url}")
    if draft.shores and (draft.layer != "pais" or not event.both_sides):
        problems.append("Las dos orillas only for politics covered by both sides")
    if draft.stance and any(v not in (-1, 0, 1) for v in vars(draft.stance).values()):
        problems.append("stance values must be -1, 0 or 1")
    return problems


def to_content(draft: WaveDraft, event: Event) -> dict[str, Any]:
    """The JSON the app shows (ondas.contenido)."""
    outlets = sorted({BY_ID[i.outlet].name for i in event.items})
    stance = None
    if draft.stance:
        stance = {k: v for k, v in vars(draft.stance).items() if v != 0} or None
    return {
        "cards": [c.model_dump() for c in draft.cards],
        "shores": draft.shores.model_dump() if draft.shores else None,
        "stance": stance,
        "source": " · ".join(outlets),
        "links": [{"outlet": BY_ID[i.outlet].name, "url": i.url} for i in event.items],
    }


# --------------------------------------------------------------------------
# Database
# --------------------------------------------------------------------------

def recent_items(conn: psycopg.Connection) -> list[Item]:
    rows = conn.execute(
        "select id, outlet, title, url from public.noticias"
        " where coalesce(published_at, fetched_at) > now() - interval '24 hours' order by id"
    ).fetchall()
    return [Item(r[0], r[1], r[2], r[3]) for r in rows]


def already_covered(conn: psycopg.Connection, event: Event) -> bool:
    """True if an event from the last 2 days shares at least half of these headlines."""
    ids = [i.id for i in event.items]
    row = conn.execute(
        "select 1 from public.eventos where created_at > now() - interval '48 hours'"
        " and cardinality(array(select unnest(noticia_ids) intersect select unnest(%s::bigint[]))) * 2 >= %s"
        " limit 1",
        (ids, len(ids)),
    ).fetchone()
    return row is not None


def save(conn: psycopg.Connection, event: Event, draft: WaveDraft) -> int:
    with conn.transaction():
        evento_id = conn.execute(
            "insert into public.eventos (headline, noticia_ids, outlets, sides) values (%s, %s, %s, %s) returning id",
            (event.headline, [i.id for i in event.items], len(event.outlets), sorted(event.sides)),
        ).fetchone()[0]
        return conn.execute(
            "insert into public.ondas (evento_id, capa, contenido, verificar, modelo)"
            " values (%s, %s, %s, %s, %s) returning id",
            (evento_id, draft.layer, json.dumps(to_content(draft, event), ensure_ascii=False),
             json.dumps([c.model_dump() for c in draft.claims], ensure_ascii=False), MODEL),
        ).fetchone()[0]


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="list candidate events, no Claude calls")
    parser.add_argument("--max", type=int, default=MAX_DRAFTS, help="drafts to create")
    args = parser.parse_args(argv)

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set")
        return 2
    today = datetime.now(MADRID).date()
    client = None if args.dry_run else anthropic.Anthropic()

    created = 0
    with psycopg.connect(database_url, prepare_threshold=None, autocommit=True) as conn:
        events = [e for e in cluster(recent_items(conn)) if not already_covered(conn, e)][:MAX_CANDIDATES]
        log.info("%d candidate events", len(events))
        for event in events:
            log.info("[%d outlets, %s] %s", len(event.outlets), "/".join(sorted(event.sides)), event.headline)
            if client is None:
                continue
            try:
                draft = write_draft(client, event, today)
            except DraftRefused as e:
                log.warning("  skipped: %s", e)
                continue
            except anthropic.RateLimitError:
                log.error("  rate limited; stopping for today")
                break
            except anthropic.APIStatusError as e:
                log.error("  API error %s: %s", e.status_code, e.message)
                continue
            except anthropic.APIConnectionError as e:
                log.error("  connection error: %s", e)
                continue
            if not draft.relevant:
                log.info("  not relevant: %s", draft.relevance_reason)
                continue
            problems = check_draft(draft, event)
            if problems:
                log.warning("  rejected draft: %s", "; ".join(problems))
                continue
            onda_id = save(conn, event, draft)
            created += 1
            log.info("  draft %d saved (%s)", onda_id, draft.layer)
            if created >= args.max:
                break
    log.info("%d drafts waiting for review", created)
    return 0


if __name__ == "__main__":
    sys.exit(main())
