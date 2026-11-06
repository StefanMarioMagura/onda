"""Tests for the human review step."""

from datetime import date

from onda_workers.news import generate as g
from onda_workers.news.review import Draft, approve, discard, format_draft, pending

from .conftest import requires_db
from .test_news_generate import EVENT, good_draft, insert_headlines


def draft_view():
    return Draft(
        id=7, capa="pais", headline=EVENT.headline,
        contenido=g.to_content(good_draft(), EVENT),
        verificar=[c.model_dump() for c in good_draft().claims],
    )


def test_view_shows_the_four_steps_shores_and_claims_with_links():
    text = format_draft(draft_view())
    for step in ["QUÉ PASÓ", "POR QUÉ IMPORTA", "CÓMO TE LLEGA", "QUÉ HACES"]:
        assert step in text
    assert "LAS DOS ORILLAS" in text
    assert "AFIRMACIONES A VERIFICAR" in text
    assert "https://eldiario.es/a" in text
    assert "• Revisa tu nómina de enero." in text


@requires_db
def test_approve_publishes_for_a_day_once(conn):
    onda_id = g.save(conn, insert_headlines(conn), good_draft())
    assert [d.id for d in pending(conn)] == [onda_id]
    assert approve(conn, onda_id, date(2026, 11, 7))
    assert pending(conn) == []
    estado, day = conn.execute("select estado, publicada_para from public.ondas where id = %s", (onda_id,)).fetchone()
    assert (estado, day) == ("publicada", date(2026, 11, 7))
    assert not approve(conn, onda_id, date(2026, 11, 8))          # already reviewed


@requires_db
def test_discard_keeps_the_reason(conn):
    onda_id = g.save(conn, insert_headlines(conn), good_draft())
    assert discard(conn, onda_id, "Titulares insuficientes")
    estado, note = conn.execute("select estado, nota_revision from public.ondas where id = %s", (onda_id,)).fetchone()
    assert (estado, note) == ("descartada", "Titulares insuficientes")
