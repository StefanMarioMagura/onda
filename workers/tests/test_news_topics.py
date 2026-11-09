"""Tests for publishing the day's topics, and what the app may read (RLS)."""

from onda_workers.news.cluster import Event, Item
from onda_workers.news.topics import headlines_json, prune, publish, recent_items

import psycopg
import pytest

from .conftest import requires_db


def event(start=1, title="El Gobierno aprueba subir el salario mínimo"):
    items = (
        Item(start, "eldiario", title, f"https://eldiario.es/{start}", "Entradilla de elDiario."),
        Item(start + 1, "abc", f"{title} a 1.250 euros", f"https://abc.es/{start}"),
        Item(start + 2, "bbcmundo", f"{title} en España", f"https://bbc.com/{start}"),
    )
    return Event(items, items[0])


def test_headlines_keep_each_outlets_real_title_and_side():
    rows = headlines_json(event())
    assert {"outlet": "ABC", "side": "derecha", "title": "El Gobierno aprueba subir el salario mínimo a 1.250 euros",
            "url": "https://abc.es/1"} in rows
    assert {r["side"] for r in rows} == {"izquierda", "derecha", "internacional"}
    assert [r["outlet"] for r in rows] == ["ABC", "BBC Mundo", "elDiario.es"]


@requires_db
def test_publish_ranks_topics_and_replaces_the_previous_ranking(conn):
    a, b = event(1, "Primera historia de prueba"), event(10, "Segunda historia de prueba")
    publish(conn, [a, b])
    assert conn.execute("select key, rank from public.eventos order by rank").fetchall() == [("tema-1", 1), ("tema-10", 2)]

    publish(conn, [b])
    assert conn.execute("select key, rank from public.eventos where rank is not null").fetchall() == [("tema-10", 1)]
    assert conn.execute("select count(*) from public.eventos").fetchone()[0] == 2     # the old topic keeps its row


@requires_db
def test_republishing_updates_the_same_topic(conn):
    publish(conn, [event()])
    grown = event()
    extra = (*grown.items, Item(4, "rtve", "Una cuarta versión", "https://rtve.es/4"))
    publish(conn, [Event(extra, grown.lead)])
    outlets, count = conn.execute("select outlets, (select count(*) from public.eventos) from public.eventos").fetchone()
    assert (outlets, count) == (4, 1)


@requires_db
def test_recent_items_skips_old_headlines_and_unknown_outlets(conn):
    conn.execute(
        """
        insert into public.noticias (outlet, title, url, published_at) values
          ('abc', 'Reciente de ABC', 'https://a.es/1', now()),
          ('abc', 'Antigua de ABC', 'https://a.es/2', now() - interval '3 days'),
          ('retirado', 'De un medio retirado', 'https://a.es/3', now())
        """
    )
    assert [i.title for i in recent_items(conn)] == ["Reciente de ABC"]


@requires_db
def test_prune_removes_old_headlines_and_old_topics_but_not_current_ones(conn):
    conn.execute(
        """
        insert into public.noticias (outlet, title, url, fetched_at) values
          ('abc', 'Noticia antigua', 'https://a.es/old', now() - interval '8 days'),
          ('abc', 'Noticia nueva', 'https://a.es/new', now())
        """
    )
    publish(conn, [event(1, "Tema actual de prueba")])
    conn.execute(
        "insert into public.eventos (key, rank, headline, noticia_ids, outlets, sides, created_at) values"
        " ('tema-old', null, 'Tema antiguo', '{}', 3, '{}', now() - interval '8 days')"
    )
    prune(conn)
    assert [r[0] for r in conn.execute("select title from public.noticias")] == ["Noticia nueva"]
    assert [r[0] for r in conn.execute("select key from public.eventos")] == ["tema-1"]


@requires_db
def test_the_app_reads_current_topics_and_headlines_but_nothing_internal(conn):
    publish(conn, [event(1, "Tema actual de prueba"), event(10, "Tema que dejará de estar")])
    publish(conn, [event(1, "Tema actual de prueba")])
    conn.execute("insert into public.noticias (outlet, outlet_name, title, url) values"
                 " ('abc', 'ABC', 'Un titular', 'https://a.es/1')")
    conn.execute("grant usage on schema public to anon")
    conn.execute("set role anon")
    try:
        assert [r[0] for r in conn.execute("select key from public.eventos")] == ["tema-1"]
        assert conn.execute("select outlet_name, title from public.noticias").fetchall() == [("ABC", "Un titular")]
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            conn.execute("select noticia_ids from public.eventos")
    finally:
        conn.rollback()
