# Medios y su orilla

**Fecha:** 2026-11-09 · **Estado:** provisional, pendiente de validar

ONDA lee estos medios por RSS. Cada uno tiene una **orilla**, que solo sirve para una cosa: agrupar
los titulares de cada lado en "Las dos orillas". No se usa para ordenar ni recomendar noticias.

| Medio | Orilla | RSS |
|---|---|---|
| elDiario.es | izquierda | `https://www.eldiario.es/rss/` |
| infoLibre | izquierda | `https://www.infolibre.es/rss` |
| El País | centroizquierda | `https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada` |
| Cadena SER | centroizquierda | `https://cadenaser.com/arc/outboundfeeds/rss/?outputType=xml` |
| El HuffPost | centroizquierda | `https://www.huffingtonpost.es/feeds/index.xml` |
| El Mundo | centroderecha | `https://e00-elmundo.uecdn.es/elmundo/rss/portada.xml` |
| ABC | derecha | `https://www.abc.es/rss/2.0/portada/` |
| El Español | centroderecha | `https://www.elespanol.com/rss/` |
| Libertad Digital | derecha | `https://feeds2.feedburner.com/libertaddigital/portada` |
| The Objective | derecha | `https://theobjective.com/feed/` |
| RTVE | centro (servicio público) | `https://api2.rtve.es/rss/temas_noticias.xml` |
| Europa Press | centro (agencia) | `https://www.europapress.es/rss/rss.aspx` |
| 20minutos | centro | `https://www.20minutos.es/rss/` |
| La Vanguardia | centro | `https://www.lavanguardia.com/rss/home.xml` |
| El Confidencial | centro | `https://rss.elconfidencial.com/espana/` |
| Newtral | centro (verificación) | `https://www.newtral.es/feed/` |
| Expansión | centro (economía) | `https://e00-expansion.uecdn.es/rss/portada.xml` |
| Cinco Días | centro (economía) | `https://feeds.elpais.com/mrss-s/pages/ep/site/cincodias.elpais.com/portada` |

## Prensa internacional en español (geopolítica)
No tienen orilla española.

| Medio | RSS |
|---|---|
| BBC Mundo | `https://feeds.bbci.co.uk/mundo/rss.xml` |
| DW Español | `https://rss.dw.com/rdf/rss-sp-all` |
| France 24 | `https://www.france24.com/es/rss` |
| RFI Español | `https://www.rfi.fr/es/rss` |
| Euronews | `https://es.euronews.com/rss` |
| Noticias ONU | `https://news.un.org/feed/subscribe/es/news/all/rss.xml` |
| El Orden Mundial | `https://elordenmundial.com/feed/` |

## Método y por qué es provisional
La clasificación sigue la línea editorial que se atribuye habitualmente a cada medio. Es un juicio
propio y, como tal, discutible. Para la versión final se sustituirá por un criterio externo y
citable: la **posición ideológica media de la audiencia de cada medio** del *Digital News Report*
del Reuters Institute (edición España), agrupando en izquierda / centro / derecha con umbrales
fijos documentados aquí.

Las orillas que usa el código son `izquierda` (izquierda y centroizquierda), `centro`, `derecha`
(derecha y centroderecha) e `internacional`. Hay tantos medios en la izquierda como en la derecha,
y un test lo comprueba.

## Fuera de la lista
- **Público** y **La Razón**: sus RSS devuelven error (404 / 503) a peticiones automatizadas.
- **El Salto** y **OKdiario**: sus RSS funcionan, pero quedan fuera por simetría: son los más
  militantes de cada lado y aquí nadie revisa los titulares antes de publicarlos. Añadirlos es una
  línea en `onda_workers/news/sources.py`.
