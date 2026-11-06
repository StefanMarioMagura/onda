"""Tests for RSS ingestion: headline + link only."""

from datetime import UTC
from pathlib import Path

import pytest

from onda_workers.news.ingest import Headline, canonical_url, clean_title, parse_feed, store
from onda_workers.news.sources import BY_ID, OUTLETS

from .conftest import requires_db

FIXTURES = Path(__file__).parent / "fixtures"


def test_rss_keeps_title_link_and_date_only():
    headlines = parse_feed(BY_ID["eldiario"], (FIXTURES / "rss_eldiario_sample.xml").read_bytes())
    assert len(headlines) == 4                       # the entry without a link is skipped
    first = headlines[0]
    assert first.outlet == "eldiario"
    assert first.published_at is not None and first.published_at.tzinfo == UTC
    assert "utm_" not in first.url                   # tracking parameters removed
    assert set(vars(first)) == {"outlet", "title", "url", "published_at"}


def test_html_in_titles_is_cleaned():
    headlines = parse_feed(BY_ID["eldiario"], (FIXTURES / "rss_eldiario_sample.xml").read_bytes())
    assert headlines[-1].title == "Con & HTML"


def test_atom_feeds_work_too():
    headlines = parse_feed(BY_ID["elconfidencial"], (FIXTURES / "atom_elconfidencial_sample.xml").read_bytes())
    assert len(headlines) == 2
    assert all(h.url.startswith("https://") for h in headlines)


@pytest.mark.parametrize("raw, clean", [
    ("https://a.es/x?utm_source=rss&id=3#top", "https://a.es/x?id=3"),
    ("https://A.ES/x?fbclid=123", "https://a.es/x"),
    ("https://a.es/x", "https://a.es/x"),
])
def test_canonical_url(raw, clean):
    assert canonical_url(raw) == clean


def test_clean_title_squeezes_whitespace_and_entities():
    assert clean_title("  Sube&nbsp;el   <i>IVA</i>  ") == "Sube el IVA"


def test_outlet_catalog_is_consistent():
    assert len({o.id for o in OUTLETS}) == len(OUTLETS)
    assert {o.side for o in OUTLETS} == {"izquierda", "centro", "derecha"}


@requires_db
def test_store_ignores_repeated_links(conn):
    h = Headline("eldiario", "Un titular de prueba", "https://a.es/1", None)
    assert store(conn, [h]) == 1
    assert store(conn, [h, Headline("abc", "Otro titular", "https://a.es/2", None)]) == 1
