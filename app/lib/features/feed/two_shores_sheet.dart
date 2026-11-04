import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/wave.dart';

/// "Las dos orillas": each side's framing side by side, then the shared facts.
Future<void> showTwoShores(BuildContext context, TwoShores shores) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text('LAS DOS ORILLAS', style: OndaText.antetitulo(color: Capa.pais.color)),
          const SizedBox(height: 8),
          Text('Cómo lo cuenta cada lado', style: OndaText.titular(28)),
          const SizedBox(height: 24),
          _Side(title: 'Quienes lo apoyan', text: shores.supporters),
          const SizedBox(height: 20),
          _Side(title: 'Quienes lo critican', text: shores.critics),
          const SizedBox(height: 28),
          const Divider(color: Palette.ink, thickness: 1.5, height: 1.5),
          const SizedBox(height: 14),
          Text('EN LO QUE COINCIDEN', style: OndaText.antetitulo(color: Palette.ink)),
          const SizedBox(height: 6),
          for (final fact in shores.sharedFacts) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(fact, style: OndaText.cuerpo(16)),
            ),
            const Divider(),
          ],
        ],
      ),
    ),
  );
}

class _Side extends StatelessWidget {
  const _Side({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: OndaText.cuerpo(13, weight: 600, color: Palette.inkSoft)),
        const SizedBox(height: 6),
        Text(text, style: OndaText.cuerpo(16)),
      ],
    );
  }
}
