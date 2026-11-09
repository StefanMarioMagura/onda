"""Publish the day's topics: groups recent headlines and stores the best covered.

Runs after each ingestion. Every topic keeps each outlet's real headline, so
"Las dos orillas" shows how each side tells it, with no writing involved.
Old headlines and topics are deleted: news is not a permanent record here.

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.news.topics
"""

from __future__ import annotations

import json
import logging
import os
import sys
from typing import Any

import psycopg

from .cluster import Event, Item, cluster, select_topics
from .sources import BY_ID

log = logging.getLogger("onda_workers.news.topics")

KEEP_DAYS = 7


def headlines_json(event: Event) -> list[dict[str, Any]]:
    """Each outlet's headline for the topic, for the "Las dos orillas" view."""
    return [
        {"outlet": BY_ID[i.outlet].name, "side": BY_ID[i.outlet].side, "title": i.title, "url": i.url}
        for i in sorted(event.items, key=lambda i: BY_ID[i.outlet].name.lower())
        if i.outlet in BY_ID
    ]


def recent_items(conn: psycopg.Connection) -> list[Item]:
    rows = conn.execute(
        "select id, outlet, title, url, summary from public.noticias"
        " where coalesce(published_at, fetched_at) > now() - interval '24 hours' order by id"
    ).fetchall()
    return [Item(*r) for r in rows if r[1] in BY_ID]


def publish(conn: psycopg.Connection, topics: list[Event]) -> None:
    """Replace the current ranking atomically: the app never sees a half-updated list."""
    with conn.transaction():
        conn.execute("update public.eventos set rank = null where rank is not null")
        for rank, event in enumerate(topics, 1):
            lead = event.lead
            conn.execute(
                """
                insert into public.eventos
                  (key, rank, headline, summary, url, outlet_name, noticia_ids, outlets, sides, headlines)
                values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                on conflict (key) do update set
                  rank = excluded.rank, headline = excluded.headline,
                  summary = excluded.summary, url = excluded.url, outlet_name = excluded.outlet_name,
                  noticia_ids = excluded.noticia_ids, outlets = excluded.outlets, sides = excluded.sides,
                  headlines = excluded.headlines, updated_at = now()
                """,
                (event.key, rank, lead.title, lead.summary, lead.url, BY_ID[lead.outlet].name,
                 [i.id for i in event.items], len(event.outlets), sorted(event.sides),
                 json.dumps(headlines_json(event), ensure_ascii=False)),
            )


def prune(conn: psycopg.Connection, keep_days: int = KEEP_DAYS) -> None:
    with conn.transaction():
        conn.execute("delete from public.noticias where fetched_at < now() - make_interval(days => %s)", (keep_days,))
        conn.execute(
            "delete from public.eventos where rank is null and created_at < now() - make_interval(days => %s)"
            " and id not in (select evento_id from public.ondas where evento_id is not null)",
            (keep_days,),
        )


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set")
        return 2
    with psycopg.connect(database_url, prepare_threshold=None, autocommit=True) as conn:
        items = recent_items(conn)
        topics = select_topics(cluster(items))
        log.info("%d recent headlines, %d topics", len(items), len(topics))
        for event in topics:
            log.info("  [%d outlets] %s", len(event.outlets), event.headline)
        if not topics:
            log.warning("No topics found: keeping the previous ones")
            return 0
        publish(conn, topics)
        prune(conn)
    return 0


if __name__ == "__main__":
    sys.exit(main())
