"""Integration tests for anonymous vote totals (votos_noticias + cast_vote)."""

import psycopg
import pytest

from .conftest import requires_db

pytestmark = requires_db


def totals(conn, item="smi"):
    return conn.execute("select bien, mal, igual from public.votos_noticias where item_id = %s", (item,)).fetchone()


def vote(conn, v, previous=None, item="smi"):
    conn.execute("select public.cast_vote(%s, %s, %s)", (item, v, previous))


def test_first_vote_creates_the_counters(conn):
    vote(conn, "bien")
    assert totals(conn) == (1, 0, 0)


def test_votes_add_up(conn):
    for v in ["bien", "bien", "mal", "igual"]:
        vote(conn, v)
    assert totals(conn) == (2, 1, 1)


def test_changing_a_vote_moves_it(conn):
    vote(conn, "bien")
    vote(conn, "mal")
    vote(conn, "mal", previous="bien")           # first voter changes their mind
    assert totals(conn) == (0, 2, 0)


def test_same_vote_again_changes_nothing(conn):
    vote(conn, "bien")
    vote(conn, "bien", previous="bien")
    assert totals(conn) == (1, 0, 0)


def test_counters_never_go_negative(conn):
    vote(conn, "mal", previous="bien")           # previous vote never counted
    assert totals(conn) == (0, 1, 0)


def test_invalid_vote_is_rejected(conn):
    with pytest.raises(psycopg.errors.RaiseException):
        vote(conn, "genial")


def test_table_stores_no_user_identifiers(conn):
    cols = {r[0] for r in conn.execute(
        "select column_name from information_schema.columns where table_name = 'votos_noticias'")}
    assert cols == {"item_id", "bien", "mal", "igual", "updated_at"}
