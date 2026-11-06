# ONDA — contexto del proyecto para Claude Code

ONDA es una app (móvil, web y PC) que explica lo que pasa en el mundo por lo que le cuesta al usuario.
Feed vertical tipo TikTok: primero las 5-8 "ondas" del día y, al terminarlas, un flujo
infinito "Descubre" (historias de política, ciencia y curiosidades) en texto, audio y clips.
Público: mayores de 18 años. Sin burbuja política.
Es mi proyecto final: prioriza código claro, explicable y bien probado sobre trucos.

## Las tres capas
- **Tu bolsillo:** precios de carburantes, semáforo "¿lleno hoy o espero?", gasolineras baratas en tu ruta.
- **Tu país:** política explicada por sus consecuencias, con "Las dos orillas" (cómo lo cuenta cada lado + hechos comunes).
- **El mundo:** solo sucesos cuya onda llega a la vida del usuario en España.

Cada onda = 4 tarjetas: qué pasó → por qué importa → cómo te llega → qué haces.

## Stack
- App: Flutter (Dart) + Riverpod + go_router. Mapas con flutter_map. Animaciones con Rive o Lottie.
- Backend: Supabase (Postgres + PostGIS, Auth, Storage). Row Level Security siempre activada.
- Workers: Python (pandas, scikit-learn/statsmodels), lanzados con GitHub Actions (cron) o pg_cron.
- IA de ondas: API de un modelo de lenguaje con salida JSON de esquema fijo. Toda onda pasa por revisión humana antes de publicarse.
- Notificaciones: Firebase Cloud Messaging. Analítica: PostHog. Errores: Sentry.

## Estructura del repositorio
```
/app          # Flutter
/workers      # Python: ingesta de precios, Brent, noticias, motor de ondas, modelo del semáforo
/supabase     # migraciones SQL y políticas RLS
/docs         # memoria del proyecto y decisiones
```

## Fuentes de datos
- Precios de todas las gasolineras: API REST de precios de carburantes del Ministerio (Geoportal de Gasolineras).
- Brent: API de la EIA (publica con ~7 días de retraso). Cambio EUR/USD: API del BCE.
- Noticias: RSS de medios + GDELT. Orientación de medios: clasificación propia documentada en /docs.
- La app NUNCA llama a fuentes externas: solo lee de Supabase.

## Tablas principales
usuarios, gasolineras, precios (histórico, nunca se borra), brent_diario, eventos, ondas,
orillas, preguntas, predicciones, interacciones.

## Reglas
- Interfaz en español de España. Código, nombres de variables y commits en inglés.
- Nunca secretos en el código: variables de entorno y GitHub Secrets.
- Cada cambio de esquema = una migración en /supabase/migrations.
- Tests para la lógica del semáforo, el cálculo de ahorro y los parsers de las fuentes.
- Feed: las ondas del día van primero y después sigue "Descubre" sin final. Nunca
  recomendación por afinidad política.
- Diseño "neón nocturno" y mecánicas de enganche: ver /docs/diseno/principios.md.
  Puntos y rachas nunca se compran ni se canjean por dinero (si no, sería juego regulado).
  Nada de cifras falsas, urgencia falsa ni bajas difíciles (DSA art. 25).
- Noticias: solo titular, enlace y resumen propio; nunca el texto completo de un medio.
- Ubicación del usuario solo aproximada (RGPD).

## Semáforo (modelo v2 "solo surtidor")
Regresión del cambio de precio a 7 días sobre dos variables que se conocen el mismo día:
la tendencia del precio en surtidor (cambio de los últimos 7 días) y la distancia del margen
(precio − Brent conocido) a su media de 90 días. Ver /docs/decisiones/0006.
El v1 (Brent de 14 días + día de la semana) se descartó: con el retraso de 7 días de la EIA
apenas mejora a la referencia (/docs/decisiones/0005).
Verde (llena hoy) si sube más de 1 cént/l, rojo (espera) si baja más de 1 cént/l, ámbar en otro caso.
Comparar siempre con la referencia "mañana igual que hoy"; un modelo que no la supere no se publica.
El backtest se repite con el workflow manual `semaforo-backtest`.

## Fase actual
F0 · Preparación: diseño en Figma, repositorio, y empezar YA a guardar el histórico de precios cada 30 min.
