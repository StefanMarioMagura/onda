"""Read outlet RSS feeds and store headline, link and a short extract.

The extract is the feed's own description, capped at SUMMARY_MAX characters.
The full text of an article is never stored: the app links to the outlet.

Usage:
    DATABASE_URL=postgresql://... python -m onda_workers.news.ingest
    python -m onda_workers.news.ingest --dry-run
"""

from __future__ import annotations

import argparse
import html
import logging
import os
import re
import sys
from calendar import timegm
from dataclasses import dataclass
from datetime import UTC, datetime
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import feedparser
import psycopg
import requests

from .sources import BY_ID, OUTLETS, Outlet

log = logging.getLogger("onda_workers.news.ingest")

SUMMARY_MAX = 280
# Boilerplate some feeds append to their descriptions.
SUMMARY_NOISE = re.compile(r"(The post .*|Continuar leyendo.*|Leer más.*|Seguir leyendo.*|\[(…|\.\.\.)\])\s*$", re.I | re.S)
TRACKING_PARAMS = re.compile(r"^(utm_|fbclid|gclid|ns_|mc_|ref$|xtor$|ito$|int$|cmp$)")


@dataclass(frozen=True)
class Headline:
    outlet: str
    title: str
    url: str
    published_at: datetime | None
    summary: str | None = None


def clean_title(raw: str) -> str:
    """Strip HTML tags and entities and squeeze whitespace."""
    text = html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))
    return re.sub(r"\s+", " ", text).strip()


def clean_summary(raw: str | None, title: str) -> str | None:
    """The feed's description as a short extract, or None if it adds nothing."""
    text = SUMMARY_NOISE.sub("", clean_title(raw or "")).strip()
    if len(text) < 20 or text.lower().startswith(title.lower()[:60]):
        return None
    if len(text) <= SUMMARY_MAX:
        return text
    return text[:SUMMARY_MAX].rsplit(" ", 1)[0].rstrip(" ,.;:") + "…"


def canonical_url(url: str) -> str:
    """Drop tracking parameters and fragments, so the same story isn't stored twice."""
    parts = urlsplit(url.strip())
    query = [(k, v) for k, v in parse_qsl(parts.query, keep_blank_values=True) if not TRACKING_PARAMS.match(k)]
    return urlunsplit((parts.scheme, parts.netloc.lower(), parts.path, urlencode(query), ""))


def parse_feed(outlet: Outlet, content: bytes) -> list[Headline]:
    """RSS or Atom -> headlines: title, link, date and a short extract, nothing else."""
    now = datetime.now(UTC)
    feed = feedparser.parse(content)
    headlines = []
    seen = set()
    for entry in feed.entries:
        title = clean_title(entry.get("title", ""))
        link = entry.get("link")
        if not link or len(title) < 5:
            continue
        url = canonical_url(link)
        if url in seen:
            continue
        seen.add(url)
        stamp = entry.get("published_parsed") or entry.get("updated_parsed")
        published = datetime.fromtimestamp(timegm(stamp), UTC) if stamp else None
        if published and published > now:           # some feeds date stories in the future
            published = now
        headlines.append(Headline(outlet.id, title[:400], url, published, clean_summary(entry.get("summary"), title)))
    return headlines


def fetch(outlet: Outlet, session: requests.Session) -> list[Headline]:
    response = session.get(outlet.rss, timeout=30)
    response.raise_for_status()
    return parse_feed(outlet, response.content)


def store(conn: psycopg.Connection, headlines: list[Headline]) -> int:
    with conn.transaction(), conn.cursor() as cur:
        cur.executemany(
            "insert into public.noticias (outlet, outlet_name, title, url, published_at, summary)"
            " values (%s, %s, %s, %s, %s, %s) on conflict (url) do nothing",
            [(h.outlet, BY_ID[h.outlet].name, h.title, h.url, h.published_at, h.summary) for h in headlines],
        )
        return cur.rowcount


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    session = requests.Session()
    session.headers["User-Agent"] = "Mozilla/5.0 (compatible; onda-workers/0.1)"
    headlines: list[Headline] = []
    failed = 0
    for outlet in OUTLETS:
        try:
            got = fetch(outlet, session)
        except requests.RequestException as e:
            failed += 1
            log.warning("%s: failed (%s)", outlet.name, e)
            continue
        log.info("%s: %d headlines", outlet.name, len(got))
        headlines.extend(got)

    if failed == len(OUTLETS):
        log.error("Every feed failed")
        return 1
    if args.dry_run:
        return 0
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set")
        return 2
    with psycopg.connect(database_url, prepare_threshold=None) as conn:
        log.info("Stored %d new headlines", store(conn, headlines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
