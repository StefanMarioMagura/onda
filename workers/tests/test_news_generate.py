"""Tests for draft generation with Claude (fake client: no network, no cost)."""

from datetime import date
from types import SimpleNamespace

import psycopg
import pytest

from onda_workers.news import generate as g
from onda_workers.news.cluster import Event, Item

from .conftest import requires_db

EVENT = Event(
    items=(
        Item(1, "eldiario", "El Gobierno aprueba subir el salario mínimo a 1.250 euros", "https://eldiario.es/a"),
        Item(2, "abc", "La patronal critica la subida del salario mínimo a 1.250 euros", "https://abc.es/b"),
        Item(3, "rtve", "Aprobada la subida del salario mínimo", "https://rtve.es/c"),
    ),
    headline="El Gobierno aprueba subir el salario mínimo a 1.250 euros",
)


def card(n, actions=(), teaser="¿Y ahora?"):
    return g.Card(headline=f"Tarjeta {n}", body="Texto breve.", figure=None,
                  teaser=None if actions else teaser, actions=list(actions))


def good_draft(**overrides):
    fields = dict(
        relevant=True,
        relevance_reason="Afecta a los sueldos más bajos.",
        layer="pais",
        cards=[card(1), card(2), card(3), card(4, actions=["Revisa tu nómina de enero."])],
        shores=g.Shores(supporters="Destacan...", critics="Advierten...", shared_facts=["Sube a 1.250 euros."]),
        stance=g.StanceOut(economia=-1, sociedad=0, territorio=0),
        claims=[g.Claim(claim="El salario mínimo sube a 1.250 euros", source_url="https://eldiario.es/a")],
    )
    fields.update(overrides)
    return g.WaveDraft(**fields)


class FakeClient:
    """Mimics client.beta.messages.parse and records the request."""

    def __init__(self, stop_reason="end_turn", output=None):
        self.calls = []
        self.response = SimpleNamespace(stop_reason=stop_reason, parsed_output=output)
        self.beta = SimpleNamespace(messages=SimpleNamespace(parse=self._parse))

    def _parse(self, **kwargs):
        self.calls.append(kwargs)
        return self.response


# --- the request ---------------------------------------------------------------

def test_request_uses_current_model_fallback_effort_and_schema():
    client = FakeClient(output=good_draft())
    g.write_draft(client, EVENT, date(2026, 11, 6))
    [req] = client.calls
    assert req["model"] == "claude-opus-5-5"
    assert req["fallbacks"] == "default" and req["betas"] == ["server-side-fallback-2026-07-01"]
    assert req["output_config"] == {"effort": "high"}
    assert req["output_format"] is g.WaveDraft
    assert req["max_tokens"] >= 16000


def test_user_message_has_each_headline_with_outlet_side_and_link_only():
    message = g.build_user_message(EVENT, date(2026, 11, 6))
    assert "Fecha: 2026-11-06" in message
    assert "[elDiario.es · izquierda] El Gobierno aprueba subir el salario mínimo a 1.250 euros — https://eldiario.es/a" in message
    assert "[ABC · derecha]" in message and "[RTVE · centro]" in message


def test_system_prompt_forbids_inventing_facts():
    assert "usa solo lo que dicen los titulares" in g.SYSTEM_PROMPT
    assert "revisará" in g.SYSTEM_PROMPT


@pytest.mark.parametrize("stop_reason", ["refusal", "max_tokens"])
def test_refused_or_truncated_output_raises(stop_reason):
    with pytest.raises(g.DraftRefused):
        g.write_draft(FakeClient(stop_reason=stop_reason, output=None), EVENT, date(2026, 11, 6))


# --- checks ----------------------------------------------------------------------

def test_good_draft_has_no_problems():
    assert g.check_draft(good_draft(), EVENT) == []


def test_needs_exactly_four_cards():
    draft = good_draft(cards=[card(1), card(2), card(3, actions=["x"])])
    assert "3 cards instead of 4" in g.check_draft(draft, EVENT)


def test_actions_only_on_the_last_card():
    draft = good_draft(cards=[card(1, actions=["x"]), card(2), card(3), card(4, actions=["y"])])
    assert "actions must appear only on card 4" in g.check_draft(draft, EVENT)


def test_claims_must_cite_given_links():
    draft = good_draft(claims=[g.Claim(claim="Algo", source_url="https://invented.example/x")])
    assert any("not given" in p for p in g.check_draft(draft, EVENT))


def test_claims_are_required():
    assert "no claims to verify" in g.check_draft(good_draft(claims=[]), EVENT)


def test_two_shores_only_for_politics():
    assert any("dos orillas" in p for p in g.check_draft(good_draft(layer="bolsillo"), EVENT))


def test_two_shores_need_both_sides():
    one_side = Event(items=EVENT.items[:1] + EVENT.items[2:], headline=EVENT.headline)
    assert any("dos orillas" in p for p in g.check_draft(good_draft(), one_side))


def test_stance_values_are_bounded():
    draft = good_draft(stance=g.StanceOut(economia=3, sociedad=0, territorio=0))
    assert "stance values must be -1, 0 or 1" in g.check_draft(draft, EVENT)


def test_content_for_the_app_drops_zero_axes_and_lists_sources():
    content = g.to_content(good_draft(), EVENT)
    assert content["stance"] == {"economia": -1}
    assert content["source"] == "ABC · RTVE · elDiario.es"
    assert len(content["cards"]) == 4
    assert {"outlet": "ABC", "url": "https://abc.es/b"} in content["links"]


# --- database (integration) ---------------------------------------------------------

def insert_headlines(conn):
    for item in EVENT.items:
        conn.execute("insert into public.noticias (outlet, title, url) values (%s, %s, %s)",
                     (item.outlet, item.title, item.url))
    rows = conn.execute("select id, outlet, title, url from public.noticias order by id").fetchall()
    return Event(items=tuple(Item(*r) for r in rows), headline=EVENT.headline)


@requires_db
def test_save_stores_a_draft_and_recent_items_reads_headlines(conn):
    event = insert_headlines(conn)
    assert len(g.recent_items(conn)) == 3
    onda_id = g.save(conn, event, good_draft())
    estado, capa = conn.execute("select estado, capa from public.ondas where id = %s", (onda_id,)).fetchone()
    assert (estado, capa) == ("borrador", "pais")
    assert g.already_covered(conn, event)


@requires_db
def test_the_app_sees_only_published_ondas_and_never_the_claims(conn):
    event = insert_headlines(conn)
    draft_id = g.save(conn, event, good_draft())
    published_id = g.save(conn, event, good_draft())
    conn.execute("update public.ondas set estado = 'publicada', publicada_para = current_date where id = %s",
                 (published_id,))
    conn.execute("grant usage on schema public to anon")
    conn.execute("set role anon")
    try:
        rows = conn.execute("select id, capa, contenido, publicada_para from public.ondas").fetchall()
        assert [r[0] for r in rows] == [published_id]
        assert draft_id not in [r[0] for r in rows]
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            conn.execute("select verificar from public.ondas")
    finally:
        conn.rollback()
