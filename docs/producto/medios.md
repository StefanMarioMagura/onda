# Medios y su orilla

**Fecha:** 2026-11-06 · **Estado:** provisional, pendiente de validar

ONDA lee los titulares de estos medios por RSS. Cada uno tiene una **orilla**, que solo sirve
para una cosa: que "Las dos orillas" de cada onda se escriba con titulares de los dos lados.
No se usa para ordenar ni recomendar noticias.

| Medio | Orilla | RSS |
|---|---|---|
| elDiario.es | izquierda | `https://www.eldiario.es/rss/` |
| infoLibre | izquierda | `https://www.infolibre.es/rss` |
| El País | centroizquierda | `https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada` |
| El Mundo | centroderecha | `https://e00-elmundo.uecdn.es/elmundo/rss/portada.xml` |
| ABC | derecha | `https://www.abc.es/rss/2.0/portada/` |
| El Español | centroderecha | `https://www.elespanol.com/rss/` |
| Libertad Digital | derecha | `https://feeds2.feedburner.com/libertaddigital/portada` |
| RTVE | centro (servicio público) | `https://api2.rtve.es/rss/temas_noticias.xml` |
| Europa Press | centro (agencia) | `https://www.europapress.es/rss/rss.aspx` |
| 20minutos | centro | `https://www.20minutos.es/rss/` |
| La Vanguardia | centro | `https://www.lavanguardia.com/rss/home.xml` |
| El Confidencial | centro | `https://rss.elconfidencial.com/espana/` |

## Método y por qué es provisional
La clasificación sigue la línea editorial que se atribuye habitualmente a cada medio. Es un juicio
propio y, como tal, discutible. Para la versión final se sustituirá por un criterio externo y
citable: la **posición ideológica media de la audiencia de cada medio** del *Digital News Report*
del Reuters Institute (edición España), agrupando en izquierda / centro / derecha con umbrales
fijos documentados aquí.

Las tres orillas que usa el código son `izquierda` (izquierda y centroizquierda), `centro` y
`derecha` (derecha y centroderecha).

## Fuera de la lista
- **Público** y **La Razón**: sus RSS devuelven error (404 / 503) a peticiones automatizadas.
