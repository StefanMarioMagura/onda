"""Group headlines about the same story into events.

Headlines are compared with TF-IDF over words (Spanish stop words removed,
accents folded) and cosine similarity. Two headlines from *different* outlets
above THRESHOLD are linked, and linked headlines form one event (connected
components). An event matters when several outlets cover it.
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from .sources import BY_ID, CENTRO, DERECHA, INTERNACIONAL, IZQUIERDA

THRESHOLD = 0.32
MIN_OUTLETS = 3

# Common Spanish words that carry no topic, plus headline filler.
STOP_WORDS = sorted(set("""
a al algo algunos ante antes aqui asi aun bajo bien cada como con contra cual cuando de del desde donde
dos el ella ellos en entre era es esa ese eso esta este esto estos fue ha hace han hasta hay la las le
les lo los mas me mi mientras muy nada ni no nos o otra otro para pero por porque que quien se sea ser
si sin sobre son su sus tambien tan tanto te todo todos tras tu un una uno unos y ya yo
dice dicen tras segun asi hoy ayer manana ultima hora directo video fotos claves esto es lo que
""".split()))


@dataclass(frozen=True)
class Item:
    id: int
    outlet: str
    title: str
    url: str = ""
    summary: str | None = None


@dataclass(frozen=True)
class Event:
    items: tuple[Item, ...]
    lead: Item                    # most representative headline

    @property
    def headline(self) -> str:
        return self.lead.title

    @property
    def key(self) -> str:
        """Stable across hourly runs: the oldest headline's id stays while the story grows."""
        return f"tema-{min(i.id for i in self.items)}"

    @property
    def outlets(self) -> set[str]:
        return {i.outlet for i in self.items}

    @property
    def sides(self) -> set[str]:
        return {BY_ID[o].side for o in self.outlets if o in BY_ID}

    @property
    def both_sides(self) -> bool:
        return IZQUIERDA in self.sides and DERECHA in self.sides

    @property
    def international(self) -> bool:
        """Carried by at least two foreign outlets. Only used to keep room for world news:
        too rough to show as a label (a Spanish story can be covered abroad and vice versa)."""
        return sum(1 for o in self.outlets if o in BY_ID and BY_ID[o].side == INTERNACIONAL) >= 2

    def score(self) -> tuple[int, int, int]:
        """Rank: more outlets first, then events seen by both sides, then the centre too."""
        return (len(self.outlets), int(self.both_sides), int(CENTRO in self.sides))


def normalise(text: str) -> str:
    folded = unicodedata.normalize("NFKD", text.lower()).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9 ]+", " ", folded)


def cluster(items: Sequence[Item], threshold: float = THRESHOLD, min_outlets: int = MIN_OUTLETS) -> list[Event]:
    """Events covered by at least `min_outlets` outlets, best first."""
    if len(items) < 2:
        return []
    vectors = TfidfVectorizer(
        preprocessor=normalise, stop_words=STOP_WORDS, ngram_range=(1, 2), min_df=1, sublinear_tf=True,
    ).fit_transform([i.title for i in items])
    sim = cosine_similarity(vectors)

    parent = list(range(len(items)))

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    rows, cols = np.where(np.triu(sim, k=1) >= threshold)
    for a, b in zip(rows, cols):
        if items[a].outlet != items[b].outlet:          # the same outlet's two takes don't make a story
            parent[find(a)] = find(b)

    groups: dict[int, list[int]] = {}
    for idx in range(len(items)):
        groups.setdefault(find(idx), []).append(idx)

    events = []
    for members in groups.values():
        if len({items[m].outlet for m in members}) < min_outlets:
            continue
        # Representative: the headline most similar to the rest of its group,
        # preferring one with an extract to show under it.
        best = max(members, key=lambda m: (items[m].summary is not None, sim[m, members].sum()))
        events.append(Event(tuple(items[m] for m in members), items[best]))
    return sorted(events, key=lambda e: e.score(), reverse=True)


def select_topics(events: Sequence[Event], total: int = 8, min_world: int = 2) -> list[Event]:
    """The day's topics: best covered first, keeping room for world news (geopolitics)."""
    chosen = list(events[:total])
    missing = min_world - sum(e.international for e in chosen)
    extra = [e for e in events[total:] if e.international][:max(missing, 0)]
    for world_event in extra:
        replaceable = [e for e in chosen if not e.international]
        if replaceable:
            chosen.remove(replaceable[-1])          # the least covered
            chosen.append(world_event)
    return sorted(chosen, key=lambda e: e.score(), reverse=True)
