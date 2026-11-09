import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/news.dart';
import '../shared/links.dart';

/// "Las dos orillas": every outlet's real headline for the topic, grouped by
/// side, so the framing speaks for itself. Each headline opens its article.
Future<void> showTwoShores(BuildContext context, NewsTopic topic) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(topic.bothSides ? 'LAS DOS ORILLAS' : 'CÓMO LO CUENTAN',
              style: OndaText.etiqueta(color: Palette.lime, size: 12)),
          const SizedBox(height: 6),
          Text('EL MISMO TEMA, ${topic.headlines.length} TITULARES', style: OndaText.impacto(32)),
          const SizedBox(height: 6),
          Text('Titulares tal como los publica cada medio. Toca uno para leerlo.',
              style: OndaText.cuerpo(14, color: Palette.textSoft)),
          const SizedBox(height: 18),
          for (final MapEntry(key: side, value: headlines) in topic.bySide.entries) ...[
            _SideBlock(side: side, headlines: headlines),
            const SizedBox(height: 16),
          ],
          Text('La orilla de cada medio es una clasificación editorial orientativa.',
              style: OndaText.cuerpo(11, color: Palette.textFaint)),
        ],
      ),
    ),
  );
}

Color _sideColor(NewsSide side) => switch (side) {
      NewsSide.izquierda => Palette.sideLeft,
      NewsSide.derecha => Palette.sideRight,
      NewsSide.centro => Palette.text,
      NewsSide.internacional => Palette.textSoft,
    };

class _SideBlock extends StatelessWidget {
  const _SideBlock({required this.side, required this.headlines});
  final NewsSide side;
  final List<OutletHeadline> headlines;

  @override
  Widget build(BuildContext context) {
    final color = _sideColor(side);
    // Rounded box with a coloured edge: clip instead of a one-sided border,
    // which Flutter can't combine with a border radius.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: Palette.surfaceHigh,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(side.label.toUpperCase(), style: OndaText.etiqueta(color: color)),
                      for (final h in headlines) _HeadlineRow(headline: h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadlineRow extends ConsumerWidget {
  const _HeadlineRow({required this.headline});
  final OutletHeadline headline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => openLink(context, ref, headline.url),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline.title, style: OndaText.cuerpo(15, weight: 600)),
            const SizedBox(height: 2),
            Text(headline.outlet, style: OndaText.cuerpo(12, color: Palette.textSoft)),
          ],
        ),
      ),
    );
  }
}
