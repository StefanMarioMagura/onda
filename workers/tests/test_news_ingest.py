"""Tests for RSS ingestion: headline, link and a short extract, never the article."""

from datetime import UTC, datetime
from pathlib import Path

import pytest

from onda_workers.news.ingest import SUMMARY_MAX, Headline, canonical_url, clean_summary, clean_title, parse_feed, store
from onda_workers.news.sources import BY_ID, OUTLETS

from .conftest import requires_db

FIXTURES = Path(__file__).parent / "fixtures"


def test_rss_keeps_only_title_link_date_and_extract():
    headlines = parse_feed(BY_ID["eldiario"], (FIXTURES / "rss_eldiario_sample.xml").read_bytes())
    assert len(headlines) == 4                       # the entry without a link is skipped
    first = headlines[0]
    assert first.outlet == "eldiario"
    assert first.published_at is not None and first.published_at.tzinfo == UTC
    assert "utm_" not in first.url                   # tracking parameters removed
    assert set(vars(first)) == {"outlet", "title", "url", "published_at", "summary"}


def test_html_in_titles_is_cleaned():
    headlines = parse_feed(BY_ID["eldiario"], (FIXTURES / "rss_eldiario_sample.xml").read_bytes())
    assert headlines[-1].title == "Con & HTML"


RSS_WITH_DESCRIPTION = b"""<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel>
<item><title>Sube el precio de la luz</title><link>https://a.es/luz</link>
<description>&lt;p&gt;La electricidad sube un 5 % este mes por la ola de frio.&lt;/p&gt;</description>
<content:encoded xmlns:content="http://purl.org/rss/1.0/modules/content/">&lt;p&gt;ARTICULO COMPLETO&lt;/p&gt;</content:encoded>
<pubDate>Mon, 01 Jan 2035 10:00:00 GMT</pubDate></item></channel></rss>"""


def test_extract_comes_from_the_description_never_the_full_article():
    [h] = parse_feed(BY_ID["abc"], RSS_WITH_DESCRIPTION)
    assert h.summary == "La electricidad sube un 5 % este mes por la ola de frio."
    assert "ARTICULO COMPLETO" not in (h.summary or "")


def test_a_date_in_the_future_becomes_now():
    [h] = parse_feed(BY_ID["abc"], RSS_WITH_DESCRIPTION)
    assert h.published_at <= datetime.now(UTC)


def test_extract_is_capped_at_a_word_boundary():
    text = clean_summary("palabra " * 100, "Titular cualquiera")
    assert len(text) <= SUMMARY_MAX + 1 and text.endswith("palabra…")


@pytest.mark.parametrize("raw", ["", None, "Corto", "Sube la luz: el detalle", "Sube la luz"])
def test_useless_extracts_are_dropped(raw):
    assert clean_summary(raw, "Sube la luz") is None


def test_feed_boilerplate_is_removed():
    raw = "La inflación baja por tercer mes consecutivo en España. Continuar leyendo"
    assert clean_summary(raw, "Titular") == "La inflación baja por tercer mes consecutivo en España."
    raw = "Texto suficientemente largo de la entradilla. The post Algo appeared first on Medio."
    assert clean_summary(raw, "Titular") == "Texto suficientemente largo de la entradilla."


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
    assert {o.side for o in OUTLETS} == {"izquierda", "centro", "derecha", "internacional"}


def test_left_and_right_have_the_same_number_of_outlets():
    sides = [o.side for o in OUTLETS]
    assert sides.count("izquierda") == sides.count("derecha")


@requires_db
def test_store_ignores_repeated_links(conn):
    h = Headline("eldiario", "Un titular de prueba", "https://a.es/1", None, "Una entradilla")
    assert store(conn, [h]) == 1
    assert store(conn, [h, Headline("abc", "Otro titular", "https://a.es/2", None)]) == 1
    row = conn.execute("select outlet_name, summary from public.noticias where url = 'https://a.es/1'").fetchone()
    assert row == ("elDiario.es", "Una entradilla")


@requires_db
def test_store_fills_in_an_extract_that_was_missing(conn):
    assert store(conn, [Headline("abc", "Titular de prueba", "https://a.es/9", None)]) == 1
    assert store(conn, [Headline("abc", "Titular de prueba", "https://a.es/9", None, "Ahora con entradilla")]) == 1
    assert conn.execute("select summary from public.noticias where url = 'https://a.es/9'").fetchone()[0] == "Ahora con entradilla"
