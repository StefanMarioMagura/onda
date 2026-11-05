import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/wave.dart';

/// "Las dos orillas": each side's framing, then the facts both accept.
Future<void> showTwoShores(BuildContext context, TwoShores shores) {
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
          Text('LAS DOS ORILLAS', style: OndaText.etiqueta(color: Palette.lime, size: 12)),
          const SizedBox(height: 6),
          Text('CÓMO LO CUENTA CADA LADO', style: OndaText.impacto(34)),
          const SizedBox(height: 20),
          _Side(title: 'Quienes lo apoyan', text: shores.supporters, color: Capa.pais.color),
          const SizedBox(height: 12),
          _Side(title: 'Quienes lo critican', text: shores.critics, color: Capa.mundo.color),
          const SizedBox(height: 24),
          Text('EN LO QUE COINCIDEN', style: OndaText.etiqueta(color: Palette.text, size: 12)),
          const SizedBox(height: 10),
          for (final fact in shores.sharedFacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.check_circle_rounded, color: Palette.lime, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(fact, style: OndaText.cuerpo(16))),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Side extends StatelessWidget {
  const _Side({required this.title, required this.text, required this.color});
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Rounded box with a coloured edge: clip instead of a one-sided border,
    // which Flutter can't combine with a border radius.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Palette.surfaceHigh,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(), style: OndaText.etiqueta(color: color)),
                      const SizedBox(height: 6),
                      Text(text, style: OndaText.cuerpo(16, color: Palette.textSoft)),
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
