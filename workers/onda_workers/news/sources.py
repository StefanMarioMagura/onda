"""Outlets whose RSS feeds ONDA reads, with their "orilla" (editorial side).

The side is used only to show each side's headlines in "Las dos orillas", never
to rank or recommend. Provisional classification, documented in
docs/producto/medios.md. International outlets have no Spanish side.
"""

from __future__ import annotations

from dataclasses import dataclass

IZQUIERDA, CENTRO, DERECHA, INTERNACIONAL = "izquierda", "centro", "derecha", "internacional"


@dataclass(frozen=True)
class Outlet:
    id: str
    name: str
    side: str
    rss: str


OUTLETS = [
    # Spain
    Outlet("eldiario", "elDiario.es", IZQUIERDA, "https://www.eldiario.es/rss/"),
    Outlet("infolibre", "infoLibre", IZQUIERDA, "https://www.infolibre.es/rss"),
    Outlet("elpais", "El País", IZQUIERDA, "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada"),
    Outlet("cadenaser", "Cadena SER", IZQUIERDA, "https://cadenaser.com/arc/outboundfeeds/rss/?outputType=xml"),
    Outlet("huffpost", "El HuffPost", IZQUIERDA, "https://www.huffingtonpost.es/feeds/index.xml"),
    Outlet("elmundo", "El Mundo", DERECHA, "https://e00-elmundo.uecdn.es/elmundo/rss/portada.xml"),
    Outlet("abc", "ABC", DERECHA, "https://www.abc.es/rss/2.0/portada/"),
    Outlet("elespanol", "El Español", DERECHA, "https://www.elespanol.com/rss/"),
    Outlet("libertaddigital", "Libertad Digital", DERECHA, "https://feeds2.feedburner.com/libertaddigital/portada"),
    Outlet("theobjective", "The Objective", DERECHA, "https://theobjective.com/feed/"),
    Outlet("rtve", "RTVE", CENTRO, "https://api2.rtve.es/rss/temas_noticias.xml"),
    Outlet("europapress", "Europa Press", CENTRO, "https://www.europapress.es/rss/rss.aspx"),
    Outlet("20minutos", "20minutos", CENTRO, "https://www.20minutos.es/rss/"),
    Outlet("lavanguardia", "La Vanguardia", CENTRO, "https://www.lavanguardia.com/rss/home.xml"),
    Outlet("elconfidencial", "El Confidencial", CENTRO, "https://rss.elconfidencial.com/espana/"),
    Outlet("newtral", "Newtral", CENTRO, "https://www.newtral.es/feed/"),
    Outlet("expansion", "Expansión", CENTRO, "https://e00-expansion.uecdn.es/rss/portada.xml"),
    Outlet("cincodias", "Cinco Días", CENTRO, "https://feeds.elpais.com/mrss-s/pages/ep/site/cincodias.elpais.com/portada"),
    # World, in Spanish
    Outlet("bbcmundo", "BBC Mundo", INTERNACIONAL, "https://feeds.bbci.co.uk/mundo/rss.xml"),
    Outlet("dw", "DW Español", INTERNACIONAL, "https://rss.dw.com/rdf/rss-sp-all"),
    Outlet("france24", "France 24", INTERNACIONAL, "https://www.france24.com/es/rss"),
    Outlet("rfi", "RFI Español", INTERNACIONAL, "https://www.rfi.fr/es/rss"),
    Outlet("euronews", "Euronews", INTERNACIONAL, "https://es.euronews.com/rss"),
    Outlet("onu", "Noticias ONU", INTERNACIONAL, "https://news.un.org/feed/subscribe/es/news/all/rss.xml"),
    Outlet("ordenmundial", "El Orden Mundial", INTERNACIONAL, "https://elordenmundial.com/feed/"),
]

BY_ID = {o.id: o for o in OUTLETS}
