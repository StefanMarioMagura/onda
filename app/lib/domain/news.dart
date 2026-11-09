// Real news, as the outlets publish them. Nothing here is written by ONDA:
// see docs/decisiones/0008-noticias-sin-ia.md.

/// Editorial side of an outlet (docs/producto/medios.md).
enum NewsSide {
  izquierda('Izquierda'),
  centro('Centro'),
  derecha('Derecha'),
  internacional('Prensa internacional');

  const NewsSide(this.label);
  final String label;
}

/// One outlet's own headline for a topic.
class OutletHeadline {
  const OutletHeadline({required this.outlet, required this.side, required this.title, required this.url});
  final String outlet;
  final NewsSide side;
  final String title;
  final String url;
}

/// One of the day's topics: a story covered by several outlets.
class NewsTopic {
  const NewsTopic({
    required this.id,
    required this.headline,
    required this.summary,
    required this.url,
    required this.outletName,
    required this.outlets,
    required this.headlines,
  });

  /// Stable id, also used for votes ("tema-123").
  final String id;

  /// The most representative outlet's headline, its extract and link.
  final String headline;
  final String? summary;
  final String url;
  final String outletName;

  /// How many outlets cover the story.
  final int outlets;
  final List<OutletHeadline> headlines;

  /// True when both the left and the right cover it: "Las dos orillas" applies.
  bool get bothSides =>
      headlines.any((h) => h.side == NewsSide.izquierda) && headlines.any((h) => h.side == NewsSide.derecha);

  /// Headlines grouped by side, in NewsSide order, skipping empty sides.
  Map<NewsSide, List<OutletHeadline>> get bySide => {
        for (final side in NewsSide.values)
          if (headlines.any((h) => h.side == side)) side: [...headlines.where((h) => h.side == side)],
      };
}

/// "hace 3 h", "hace 2 días"... null if the date is unknown.
String? timeAgo(DateTime? when, DateTime now) {
  if (when == null) return null;
  final diff = now.difference(when);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return diff.inDays == 1 ? 'hace 1 día' : 'hace ${diff.inDays} días';
}

/// Only web links may be opened: the URLs come from third-party feeds.
bool isWebLink(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}
