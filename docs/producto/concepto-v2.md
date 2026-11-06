# ONDA · concepto v2

**Fecha:** 2026-11-06

## En una frase
ONDA te cuenta lo que pasa en España y en el mundo, te deja opinar sobre cada noticia con un
gesto, y con tus opiniones te enseña dónde estás tú en el mapa político y cuánto te cuesta vivir.

## Tres pestañas
| Pestaña | Qué es |
|---|---|
| **Hoy** | El feed: ondas del día (4 tarjetas) y después "Descubre" sin final. Cada onda y cada historia se puede **valorar** deslizando un dial. |
| **Tu España** | Panel de datos de la vida en España: carburantes con semáforo, precio de la luz hora a hora, cesta de la compra (IPC de alimentos: "lo que hace un año eran 100 €, hoy cuesta…") y salario medio y mediano. Solo datos oficiales (Ministerio, Red Eléctrica, INE). |
| **Perfil** | Tu racha y tus puntos y, si lo activas, **tu mapa político**: dónde te sitúan tus valoraciones, a qué partido te pareces más, su líder y tu "familia" política. |

## Valorar una noticia
Al final de cada onda e historia aparece un dial: **deslízalo a la izquierda ("mal") o a la
derecha ("bien")**, o tócalo en el centro ("me da igual"). Vibra al soltarlo y da +5 puntos.
Votar es opcional y nunca bloquea el feed.

Los votos sirven para dos cosas:
1. **Totales anónimos por noticia** ("el 61 % lo valora bien"), que solo se muestran con votos
   reales y se guardan sin ningún identificador de usuario.
2. **Tu mapa político**, que se calcula **solo en tu móvil**.

## El mapa político: cómo se calcula
- **Tres ejes** de 0 a 10: economía (izquierda–derecha), sociedad (progresista–conservador) y
  territorio (más autogobierno–más centralismo).
- **Posición de los partidos:** Chapel Hill Expert Survey 2024 (CHES), una encuesta académica a
  expertos en política de cada país. Variables `lrecon`, `galtan` y `regions`. Es una fuente
  citable e independiente: ONDA no decide dónde está cada partido.
- **Posición de cada noticia:** el equipo editorial marca, para las noticias políticas, hacia dónde
  empuja en cada eje valorarla bien (por ejemplo, aprobar una subida del salario mínimo empuja a la
  izquierda en economía). Las noticias sin carga política no cuentan.
- **Tu posición** en cada eje es la media de tus valoraciones ponderada por esas marcas, en la
  misma escala 0–10. Hacen falta al menos 3 valoraciones por eje para mostrarla.
- **Parecido** con cada partido: distancia entre tu punto y el suyo en los ejes que ya tienes.
- **Equilibrio:** el conjunto de noticias valorables tiene que estar compensado (tantas que empujan
  a un lado como al otro). Hay un test que lo comprueba.

## Privacidad y ley
Las opiniones políticas son datos de categoría especial (RGPD, art. 9). Por eso:
- El mapa político solo se activa con **consentimiento explícito**, aparte, y se puede desactivar.
- Las valoraciones con las que se calcula **no salen del móvil**. Al servidor solo llegan
  contadores anónimos por noticia (+1 a "bien", "mal" o "me da igual"), sin usuario.
- Botón para **borrar todas tus valoraciones**.
- El perfil político **nunca** se usa para elegir qué noticias ves ni para publicidad
  (CLAUDE.md: sin recomendación por afinidad política; DSA art. 26 y 28).
- Se explica siempre cómo se calcula y de dónde salen los datos.
