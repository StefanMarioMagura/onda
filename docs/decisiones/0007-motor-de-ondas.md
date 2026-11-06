# 0007 · Motor de ondas: de titulares a ondas revisadas

**Fecha:** 2026-11-06 · **Estado:** aceptada

## Flujo
```
RSS de 12 medios ──► noticias (titular + enlace) ──► eventos (titulares agrupados)
        cada hora                                     │
                                                      ▼
                         Claude escribe un BORRADOR de onda (JSON de esquema fijo)
                                                      │
                                                      ▼
                     Revisión humana (CLI): aprobar / descartar ──► ondas publicadas ──► app
```

1. **Ingesta** (`onda_workers.news.ingest`, cada hora): lee los RSS de los medios de
   [docs/producto/medios.md](../producto/medios.md) y guarda **solo titular, enlace, medio y
   fecha** en `noticias`. Nunca la entradilla ni el texto: CLAUDE.md prohíbe reproducir texto de
   un medio, y así ni siquiera se almacena.
2. **Agrupación** (`news.cluster`): titulares de las últimas 24 h parecidos (TF-IDF + similitud
   coseno) forman un **evento**. Solo cuentan los eventos que cubren al menos 3 medios distintos:
   es la señal de que la noticia importa. Se prefieren los que cubren medios de las dos orillas.
3. **Generación** (`news.generate`, cada mañana): para los eventos con más cobertura, Claude
   (`claude-opus-5-5`) recibe los titulares, con su medio y su orilla, y devuelve una onda en un
   JSON de esquema fijo (`output_config.format`): capa, 4 tarjetas, "Las dos orillas" si es
   política, marca editorial para el mapa político y **una lista de afirmaciones a verificar**,
   cada una con el enlace que la respalda. Se guarda como **borrador**.
4. **Revisión** (`news.review`, la hace una persona): muestra cada borrador con sus afirmaciones y
   enlaces; se aprueba o se descarta. Solo lo aprobado se publica. La app solo puede leer ondas
   publicadas (RLS).

## Por qué así
- **Un solo modelo potente, una llamada por onda.** Es una tarea de redacción con criterio, no un
  agente: no hace falta un bucle de herramientas. Esfuerzo `high`. Con `fallbacks: "default"`, si
  el modelo rechaza una petición, la API la repite en otro modelo.
- **El modelo solo ve titulares.** Reduce el riesgo de copiar texto, pero también la información
  disponible: por eso el prompt prohíbe inventar cifras que no estén en los titulares y obliga a
  listar cada afirmación con su fuente. La revisión humana es obligatoria, no opcional.
- **Coste:** unas 3.000 palabras de entrada y 1.500 de salida por onda; con 8 ondas al día son
  céntimos diarios con las tarifas de Claude Opus 5.5 ($4 / $20 por millón de tokens).
- **Neutralidad:** la orilla de cada medio solo se usa para dar a Claude titulares de los dos
  lados en "Las dos orillas". Nunca para decidir qué ve cada usuario.

## Limitaciones conocidas
- La agrupación por palabras puede unir dos noticias distintas o separar una misma. Para la
  revisión humana es suficiente; se puede mejorar más adelante con embeddings.
- Público y La Razón no ofrecen RSS accesible de forma automatizada (404/503). Quedan fuera hasta
  encontrar otra vía.
- GDELT (cobertura internacional) queda para una versión posterior.
