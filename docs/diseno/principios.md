# Principios de diseño de ONDA

**Fecha:** 2026-11-04

## Estilo: editorial, no "de plantilla"
ONDA tiene que parecer un medio serio que te habla de tu dinero, no una app genérica.
La referencia son las apps del FT, The Economist o Bloomberg, no las plantillas de
apps con degradados.

- **Tipografía:** Newsreader (serif diseñada para noticias) en titulares y cifras
  destacadas; IBM Plex Sans en textos, etiquetas y datos, con números tabulares para que
  las cifras no "bailen". Las dos van incluidas en la app (licencia OFL), no se descargan de
  Google: así no hay dependencia externa y se evita el problema de RGPD de Google Fonts.
- **Color con significado:** fondo papel (`#F5F2EB`) y tinta casi negra. Cada color dice
  algo:
  - Capas: bolsillo `#0B6E4F`, país `#1F3A93`, mundo `#B8471E`.
  - Semáforo: verde `#1E8E3E`, ámbar `#D99A00`, rojo `#C62828`. Solo se usan para el semáforo.
- **Estructura con líneas, no con cajas:** filetes finos de 1 px, etiquetas pequeñas en
  versalitas ("antetítulo") y mucho aire. Sin sombras difusas, sin degradados, sin
  emojis, sin ilustraciones de relleno.
- **Los datos son la imagen:** números grandes y gráficos reales (evolución del precio)
  en lugar de dibujos.
- **Movimiento corto y funcional:** transiciones de ≤ 250 ms que explican qué ha cambiado.

## Enganche: hábito sí, manipulación no
Usamos el formato que hace adictivo a TikTok (pantalla completa, deslizar, ritmo) con un
contenido que **se acaba**. Descartamos a propósito las técnicas de las casas de apuestas:
recompensas aleatorias, "casi aciertos", urgencia falsa, miedo a perder rachas y scroll
infinito. Además de ir contra la idea de ONDA, la Ley de Servicios Digitales de la UE
(art. 25) prohíbe los patrones oscuros en plataformas online.

| Técnica | Cómo la usamos |
|---|---|
| Ritual diario | Las ondas del día salen a una hora fija, como un periódico. |
| Gesto fluido | Deslizar vertical entre ondas; tocar a derecha o izquierda entre tarjetas. |
| Progreso visible | Barra por tarjetas y contador "2 de 6". |
| Cierre que premia | Pantalla final "Ya estás al día" con lo aprendido. El feed termina. |
| Recompensa real | Ahorro acumulado en euros por seguir el semáforo. |
| Curiosidad honesta | Cada tarjeta acaba con la pregunta que responde la siguiente. |
| Notificaciones | Como máximo una al día, solo si hay algo útil. |
