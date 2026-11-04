# 0003 · Histórico diario de precios: estadísticas por provincia

**Fecha:** 2026-11-04 · **Estado:** aceptada

## Contexto
Nuestro histórico cada 30 min (ADR 0001) empezó el 2026-11-03. Para entrenar el semáforo
necesitamos años de datos, y esperar meses retrasaría todo el proyecto.

La API del Ministerio tiene un endpoint histórico, `EstacionesTerrestresHist/{dd-mm-aaaa}`,
con datos desde 2007. Devuelve todas las estaciones con los precios de ese día, en el mismo
formato que el endpoint en vivo.

Guardar ese histórico por estación no cabe en el plan gratuito de Supabase (500 MB):
en noviembre de 2025 cambiaban entre 7.000 y 11.000 precios al día, unos 430 MB por año
con índices.

## Decisión
- Tabla `precios_diarios`: una fila por (día, provincia, carburante) con media, mediana,
  mínimo, máximo y número de estaciones. `province_id = '00'` es el total de España,
  calculado sobre todas las estaciones (no como media de provincias).
- Solo los 4 carburantes principales: gasóleo A, gasolina 95 E5, gasóleo premium y
  gasolina 98 E5. Son ~211 filas al día; desde 2019 son ~600.000 filas, ~65 MB.
- La mediana es `median_low`: con un número par de estaciones toma un precio que existe
  en lugar de promediar dos.
- El worker `onda_workers.daily_history` rellena todos los días que faltan entre `--since`
  (por defecto 2019-01-01) y ayer, de más reciente a más antiguo. Cada día va en su propia
  transacción, así que se puede cortar y relanzar sin perder nada.
- El GitHub Action `ingest-daily-history` lo ejecuta una vez al día. La carga inicial se hace
  en tandas con `--limit`, porque un job de GitHub dura como máximo 6 h.
- Desde 2019 cubre el COVID (2020) y la crisis de precios de 2022, dos episodios útiles para
  que el modelo vea movimientos fuertes del Brent.

## Problema de TLS encontrado
Algunos servidores del Ministerio solo aceptan TLS 1.2 con intercambio de claves RSA
(`AES256-GCM-SHA384`). La configuración por defecto de Python no incluye esos cifrados,
y la conexión fallaba según el servidor que respondiera ("Connection reset" en GitHub,
"UNEXPECTED_EOF" en local). Esto también tumbaba la ingesta en vivo. El cliente HTTP
(`ministerio.ssl_context()`) añade solo esos dos cifrados a los de por defecto y sigue
verificando certificados. Se pierde el *forward secrecy*, pero los datos son públicos y no
enviamos nada secreto.

## Consecuencias
- El semáforo v1 se puede entrenar ya con precios nacionales y provinciales diarios.
- Se pierde el detalle por estación anterior al 2026-11-03. Si hiciera falta (por ejemplo,
  para estudiar marcas), habría que pasar al plan Pro o guardarlo comprimido en Storage.
- Los días en los que el Ministerio falla se quedan sin cargar y se reintentan en la
  siguiente ejecución.
- Aviso: el histórico en vivo por estación también crecerá unos 250 MB al año. Habrá que
  decidir antes de un año si se agrega o se pasa a Pro.

## Alternativas descartadas
- **Histórico por estación para 2 carburantes y pocos meses:** sigue siendo demasiado grande y
  da poco histórico para entrenar.
- **Plan Pro (25 $/mes):** se descarta por ahora; esta decisión no lo impide más adelante.
