"""Human review of draft ondas: nothing reaches the app without it.

Shows each draft with the claims it makes and the headline links that back
them; the reviewer approves (published for a day) or discards it.

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.news.review             # interactive
    DATABASE_URL=... python -m onda_workers.news.review --list
    DATABASE_URL=... python -m onda_workers.news.review --approve 12 [--day 2026-11-07]
    DATABASE_URL=... python -m onda_workers.news.review --discard 12 --note "Titulares insuficientes"
"""

from __future__ import annotations

import argparse
import os
import sys
import textwrap
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

import psycopg

from ..ministerio import MADRID

STEPS = ["QUÉ PASÓ", "POR QUÉ IMPORTA", "CÓMO TE LLEGA", "QUÉ HACES"]


@dataclass(frozen=True)
class Draft:
    id: int
    capa: str
    headline: str
    contenido: dict[str, Any]
    verificar: list[dict[str, str]]


def pending(conn: psycopg.Connection) -> list[Draft]:
    rows = conn.execute(
        "select o.id, o.capa, coalesce(e.headline, ''), o.contenido, o.verificar"
        " from public.ondas o left join public.eventos e on e.id = o.evento_id"
        " where o.estado = 'borrador' order by o.creada_en"
    ).fetchall()
    return [Draft(*r) for r in rows]


def format_draft(d: Draft) -> str:
    """Plain-text view for the terminal: cards, two shores, stance and claims with links."""
    wrap = lambda s, indent="    ": textwrap.fill(s, 96, initial_indent=indent, subsequent_indent=indent)  # noqa: E731
    c = d.contenido
    out = [f"── Borrador {d.id} · {d.capa.upper()} · {c.get('source', '')}", f"   Suceso: {d.headline}", ""]
    for step, card in zip(STEPS, c["cards"]):
        out.append(f"  {step}: {card['headline']}")
        out.append(wrap(card["body"]))
        if card.get("figure"):
            out.append(f"    [{card['figure']['value']} · {card['figure']['caption']}]")
        for action in card.get("actions", []):
            out.append(wrap(f"• {action}", "      "))
        out.append("")
    if c.get("shores"):
        s = c["shores"]
        out += ["  LAS DOS ORILLAS", wrap(f"A favor: {s['supporters']}"), wrap(f"En contra: {s['critics']}"),
                *[wrap(f"Coinciden: {f}") for f in s["shared_facts"]], ""]
    if c.get("stance"):
        out += [f"  Mapa político: {c['stance']}", ""]
    out.append("  AFIRMACIONES A VERIFICAR")
    for claim in d.verificar:
        out.append(wrap(f"• {claim['claim']}", "    "))
        out.append(f"      {claim['source_url']}")
    return "\n".join(out)


def approve(conn: psycopg.Connection, onda_id: int, day: date, note: str | None = None) -> bool:
    with conn.transaction():
        cur = conn.execute(
            "update public.ondas set estado = 'publicada', publicada_para = %s, revisada_en = now(),"
            " nota_revision = %s where id = %s and estado = 'borrador'",
            (day, note, onda_id),
        )
        return cur.rowcount == 1


def discard(conn: psycopg.Connection, onda_id: int, note: str | None = None) -> bool:
    with conn.transaction():
        cur = conn.execute(
            "update public.ondas set estado = 'descartada', revisada_en = now(), nota_revision = %s"
            " where id = %s and estado = 'borrador'",
            (note, onda_id),
        )
        return cur.rowcount == 1


def interactive(conn: psycopg.Connection, day: date) -> None:
    drafts = pending(conn)
    if not drafts:
        print("No hay borradores pendientes.")
        return
    for d in drafts:
        print("\n" + format_draft(d) + "\n")
        while True:
            choice = input("[a]probar · [d]escartar · [s]altar · [q]salir > ").strip().lower()
            if choice == "a":
                approve(conn, d.id, day)
                print(f"Publicada para el {day}.")
            elif choice == "d":
                discard(conn, d.id, input("Motivo (opcional): ").strip() or None)
                print("Descartada.")
            elif choice == "q":
                return
            elif choice != "s":
                continue
            break


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--approve", type=int)
    parser.add_argument("--discard", type=int)
    parser.add_argument("--note")
    parser.add_argument("--day", type=date.fromisoformat, default=None, help="feed day (default: today)")
    args = parser.parse_args(argv)

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL is not set", file=sys.stderr)
        return 2
    day = args.day or datetime.now(MADRID).date()
    with psycopg.connect(database_url, prepare_threshold=None, autocommit=True) as conn:
        if args.list:
            for d in pending(conn):
                print(f"{d.id:>5}  {d.capa:<9} {d.headline}")
        elif args.approve:
            print("Publicada." if approve(conn, args.approve, day, args.note) else "No es un borrador pendiente.")
        elif args.discard:
            print("Descartada." if discard(conn, args.discard, args.note) else "No es un borrador pendiente.")
        else:
            interactive(conn, day)
    return 0


if __name__ == "__main__":
    sys.exit(main())
