# 0008 · Noticias sin IA: titulares reales y temas automáticos

**Fecha:** 2026-11-09 · **Estado:** aceptada · Sustituye al [ADR 0007](0007-motor-de-ondas.md)

## Contexto
El ADR 0007 usaba un modelo de lenguaje para redactar "ondas" de 4 tarjetas a partir de
titulares, con revisión humana. Decisión de producto: ONDA **no depende de una IA por ahora**
(coste, dependencia de un tercero, y 30–60 minutos diarios de revisión). Quizá más adelante.

## Decisión
Las noticias se muestran tal como las publica cada medio, y el valor propio está en cómo se
organizan y comparan, que es trabajo de código.

```
RSS de 25 medios ──► noticias (titular, enlace, entradilla corta)
    cada hora                 │
                              ▼
                 temas del día (titulares agrupados, los 8 más cubiertos) ──► app
```

- **Fuentes:** 25 RSS gratuitos y sin clave (ver [medios.md](../producto/medios.md)): 18 de España
  (5 de izquierda, 5 de derecha y 8 de centro) y 7 internacionales en español para la geopolítica.
- **Temas del día** (`news.topics`, cada hora): agrupa titulares parecidos de medios distintos
  (TF-IDF + similitud coseno; al menos 3 medios), ordena por cobertura y reserva sitio para al
  menos 2 temas con prensa internacional.
- **"Las dos orillas" sin redactar nada:** cada tema guarda el titular real de cada medio, agrupado
  por orilla. Comparar "cómo lo cuenta cada lado" ya no es un resumen: se ve directamente.
- **Lo que se muestra de cada noticia:** titular, medio, enlace y entradilla del RSS, recortada a
  280 caracteres. **Nunca el artículo completo:** el botón "Leer en..." lleva al medio.
- **Limpieza:** noticias y temas antiguos se borran a los 7 días (el plan gratuito tiene 500 MB).
  Es información de paso; el histórico que nunca se borra es el de precios.

## Consecuencias
- **Coste cero** y ninguna revisión diaria: el contenido se publica solo.
- **Sin revisión humana, el contenido es el de los medios.** ONDA no comprueba los titulares; la
  calidad depende de qué fuentes se elijan. Por eso El Salto y OKdiario, que funcionan pero son los
  más militantes de cada lado, quedan fuera por simetría, y la lista es fácil de cambiar.
- **Mapa político solo con debates.** Una noticia real no tiene marca editorial (hacia dónde empuja
  en cada eje): haría falta una persona o una IA. Las noticias se valoran y suman a los contadores
  anónimos, pero no cuentan para el mapa.
- **Sin las 4 tarjetas** (qué pasó → por qué importa → cómo te llega → qué haces): requieren
  redacción. Lo que le cuesta al usuario está en "Tu España", con datos oficiales.
- **Derechos de autor:** el titular y un extracto muy breve con enlace es lo habitual en un
  agregador, pero la entradilla de 280 caracteres puede quedar fuera de la excepción europea de
  "extractos muy breves". Riesgo asumido para un proyecto final; si ONDA fuera un producto
  comercial, revisarlo con un abogado o quitar la entradilla (una línea en `news.ingest`).

## Alternativas descartadas
- **GDELT:** gratis y global, pero rechaza peticiones con frecuencia ("limit requests to one every 5
  seconds"), incluso esperando, y mezcla dominios sin filtro de calidad. Los RSS internacionales
  cubren la geopolítica de forma más fiable.
- **NewsAPI, GNews y similares:** su plan gratuito suele limitarse a desarrollo y añaden una clave
  más, para dar lo mismo que los RSS.

## Lo que queda de la etapa con IA
El código del motor está en el historial de git (commit `098a67e`). La tabla `ondas` sigue en la
base de datos, vacía y sin usar, para no borrar nada sin necesidad.
