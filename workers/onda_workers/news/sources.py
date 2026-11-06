"""Outlets whose RSS headlines ONDA reads, with their "orilla" (editorial side).

The side is used only to give Claude headlines from both sides for "Las dos
orillas", never to rank or recommend. Provisional classification, documented
in docs/producto/medios.md.
"""

from __future__ import annotations

from dataclasses import dataclass

IZQUIERDA, CENTRO, DERECHA = "izquierda", "centro", "derecha"


@dataclass(frozen=True)
class Outlet:
    id: str
    name: str
    side: str
    rss: str


OUTLETS = [
    Outlet("eldiario", "elDiario.es", IZQUIERDA, "https://www.eldiario.es/rss/"),
    Outlet("infolibre", "infoLibre", IZQUIERDA, "https://www.infolibre.es/rss"),
    Outlet("elpais", "El País", IZQUIERDA, "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada"),
    Outlet("elmundo", "El Mundo", DERECHA, "https://e00-elmundo.uecdn.es/elmundo/rss/portada.xml"),
    Outlet("abc", "ABC", DERECHA, "https://www.abc.es/rss/2.0/portada/"),
    Outlet("elespanol", "El Español", DERECHA, "https://www.elespanol.com/rss/"),
    Outlet("libertaddigital", "Libertad Digital", DERECHA, "https://feeds2.feedburner.com/libertaddigital/portada"),
    Outlet("rtve", "RTVE", CENTRO, "https://api2.rtve.es/rss/temas_noticias.xml"),
    Outlet("europapress", "Europa Press", CENTRO, "https://www.europapress.es/rss/rss.aspx"),
    Outlet("20minutos", "20minutos", CENTRO, "https://www.20minutos.es/rss/"),
    Outlet("lavanguardia", "La Vanguardia", CENTRO, "https://www.lavanguardia.com/rss/home.xml"),
    Outlet("elconfidencial", "El Confidencial", CENTRO, "https://rss.elconfidencial.com/espana/"),
]

BY_ID = {o.id: o for o in OUTLETS}
