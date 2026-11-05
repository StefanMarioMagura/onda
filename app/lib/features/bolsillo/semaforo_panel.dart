import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/format.dart';
import '../../domain/fuel.dart';
import '../../domain/semaforo.dart';

Color signalColor(Signal s) => switch (s) {
      Signal.verde => Palette.verde,
      Signal.ambar => Palette.ambar,
      Signal.rojo => Palette.rojo,
    };

/// The answer to "¿lleno hoy o espero?": three lights, the verdict and why.
class SemaforoPanel extends StatelessWidget {
  const SemaforoPanel({super.key, required this.pocket});
  final PocketSnapshot pocket;

  @override
  Widget build(BuildContext context) {
    final signal = pocket.signal;
    final color = signalColor(signal);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('¿LLENO HOY O ESPERO?', style: OndaText.etiqueta(size: 12))),
              _Lights(active: signal),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              signal.verdict.toUpperCase(),
              key: ValueKey(signal),
              style: OndaText.impacto(68, color: color)
                  .copyWith(shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 30)]),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(style: OndaText.cuerpo(17), children: [
              TextSpan(text: '${signal.trend} '),
              TextSpan(text: cents(pocket.expectedChange7d.abs(), signed: false),
                  style: OndaText.cuerpo(17, weight: 800, color: color)),
              const TextSpan(text: ' por litro en 7 días.'),
            ]),
          ),
          const SizedBox(height: 10),
          Text(pocket.reason, style: OndaText.cuerpo(14, color: Palette.textSoft)),
        ],
      ),
    );
  }
}

/// Rojo · ámbar · verde as three lights; only the active one glows.
class _Lights extends StatelessWidget {
  const _Lights({required this.active});
  final Signal active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in [Signal.rojo, Signal.ambar, Signal.verde])
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(left: 6),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s == active ? signalColor(s) : Palette.line,
              boxShadow: s == active ? [BoxShadow(color: signalColor(s), blurRadius: 12)] : null,
            ),
          ),
      ],
    );
  }
}
