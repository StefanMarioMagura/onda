# ONDA — contexto del proyecto para Claude Code

ONDA es una app (móvil, web y PC) que explica lo que pasa en el mundo por lo que le cuesta al usuario.
Feed vertical tipo TikTok: primero los temas del día (noticias reales de 25 medios) y, al terminarlos,
un flujo infinito "Descubre" (más noticias, historias, debates y quizzes) en texto, audio y clips.
Público: mayores de 18 años. Sin burbuja política. **Sin IA por ahora** (/docs/decisiones/0008).
Es mi proyecto final: prioriza código claro, explicable y bien probado sobre trucos.

## Concepto (v2, ver /docs/producto/concepto-v2.md)
Tres pestañas:
- **Hoy:** temas del día y Descubre. Cada noticia se valora deslizando un dial (bien / mal / me da igual).
- **Tu España:** panel de datos reales de la vida en España: carburantes con semáforo, luz por horas, cesta de la compra (IPC de alimentos) y salario medio y mediano (INE).
- **Perfil:** racha, puntos y, con consentimiento explícito, el mapa político del usuario (3 ejes) y el partido al que más se parece.

Cada tema del día = titular, entradilla y enlace del medio, cuántos medios lo cubren y "Las dos
orillas": el titular real de cada medio, agrupado por lado.

## Stack
- App: Flutter (Dart) + Riverpod + go_router. Mapas con flutter_map. Animaciones con Rive o Lottie.
- Backend: Supabase (Postgres + PostGIS, Auth, Storage). Row Level Security siempre activada.
- Workers: Python (pandas, scikit-learn/statsmodels), lanzados con GitHub Actions (cron) o pg_cron.
- Notificaciones: Firebase Cloud Messaging. Analítica: PostHog. Errores: Sentry.

## Estructura del repositorio
```
/app          # Flutter
/workers      # Python: ingesta de precios, Brent, luz, INE, noticias y temas del día, modelo del semáforo
/supabase     # migraciones SQL y políticas RLS
/docs         # memoria del proyecto y decisiones
```

## Fuentes de datos
- Precios de todas las gasolineras: API REST de precios de carburantes del Ministerio (Geoportal de Gasolineras).
- Brent: API de la EIA (publica con ~7 días de retraso). Cambio EUR/USD: API del BCE.
- Noticias: RSS de 25 medios gratuitos, ver /docs/producto/medios.md (orilla de cada medio, provisional).
- Luz: API REData de Red Eléctrica (PVPC por horas). Partidos: CHES 2024 (chesdata.eu).
- IPC (alimentos y general) y salarios (Encuesta Anual de Estructura Salarial): API Tempus del INE, tabla `indicadores`.
- La app NUNCA llama a fuentes externas: solo lee de Supabase.

## Tablas principales
usuarios, gasolineras, precios (histórico, nunca se borra), precios_diarios, brent_diario,
semaforo_diario (previsión diaria del semáforo), luz_horaria, indicadores (INE), noticias, eventos
(temas del día), votos_noticias (contadores anónimos). `ondas` sigue vacía, sin usar (ADR 0008).

## Reglas
- Interfaz en español de España. Código, nombres de variables y commits en inglés.
- Nunca secretos en el código: variables de entorno y GitHub Secrets.
- Cada cambio de esquema = una migración en /supabase/migrations.
- Tests para la lógica del semáforo, el cálculo de ahorro y los parsers de las fuentes.
- Feed: los temas del día van primero y después sigue "Descubre" sin final. Nunca
  recomendación por afinidad política.
- Diseño "neón nocturno" y mecánicas de enganche: ver /docs/diseno/principios.md.
  Puntos y rachas nunca se compran ni se canjean por dinero (si no, sería juego regulado).
  Nada de cifras falsas, urgencia falsa ni bajas difíciles (DSA art. 25).
- Noticias: titular, enlace y entradilla del RSS (máx. 280 caracteres); nunca el artículo completo.
- Ubicación del usuario solo aproximada (RGPD).
- Mapa político: posiciones de partidos del Chapel Hill Expert Survey (CHES), nunca inventadas.
  Solo cuentan los debates de Descubre, que llevan marca editorial; las noticias reales no.
  Las valoraciones del usuario se quedan en su móvil; al servidor solo van contadores anónimos.
  Consentimiento explícito aparte (RGPD art. 9) y nunca se usa para elegir contenido ni publicidad.

## Semáforo (modelo v2 "solo surtidor")
Regresión del cambio de precio a 7 días sobre dos variables que se conocen el mismo día:
la tendencia del precio en surtidor (cambio de los últimos 7 días) y la distancia del margen
(precio − Brent conocido) a su media de 90 días. Ver /docs/decisiones/0006.
El v1 (Brent de 14 días + día de la semana) se descartó: con el retraso de 7 días de la EIA
apenas mejora a la referencia (/docs/decisiones/0005).
Verde (llena hoy) si sube más de 1 cént/l, rojo (espera) si baja más de 1 cént/l, ámbar en otro caso.
Comparar siempre con la referencia "mañana igual que hoy"; un modelo que no la supere no se publica.
El backtest se repite con el workflow manual `semaforo-backtest`; la previsión diaria la
calcula el workflow `semaforo-daily` y se guarda en `semaforo_diario`.

## Fase actual
Prototipo funcional con datos reales: noticias, carburantes y semáforo, luz, IPC y salarios. Falta: selector
de zona, cuentas de usuario (ahorro real, límite de votos), notificaciones y publicación.
