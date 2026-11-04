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

/// The answer to "¿lleno hoy o espero?": a three-step scale, the verdict and why.
class SemaforoPanel extends StatelessWidget {
  const SemaforoPanel({super.key, required this.pocket});
  final PocketSnapshot pocket;

  @override
  Widget build(BuildContext context) {
    final signal = pocket.signal;
    final color = signalColor(signal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿LLENO HOY O ESPERO?', style: OndaText.antetitulo()),
        const SizedBox(height: 14),
        _Scale(active: signal),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(signal.verdict, key: ValueKey(signal), style: OndaText.titular(52, color: color)),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(style: OndaText.cuerpo(17), children: [
            TextSpan(text: '${signal.trend} '),
            TextSpan(text: cents(pocket.expectedChange7d.abs(), signed: false), style: OndaText.cuerpo(17, weight: 600)),
            TextSpan(text: ' por litro en los próximos 7 días.'),
          ]),
        ),
        const SizedBox(height: 14),
        Text('Por qué: ${pocket.reason}', style: OndaText.cuerpo(14, color: Palette.inkSoft)),
      ],
    );
  }
}

/// Rojo · Ámbar · Verde as a horizontal scale; only the active step is coloured.
class _Scale extends StatelessWidget {
  const _Scale({required this.active});
  final Signal active;

  @override
  Widget build(BuildContext context) {
    const order = [Signal.rojo, Signal.ambar, Signal.verde];
    const labels = {Signal.rojo: 'Espera', Signal.ambar: 'Da igual', Signal.verde: 'Llena'};
    return Row(
      children: [
        for (final (i, s) in order.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: s == active ? 8 : 4,
                  color: s == active ? signalColor(s) : Palette.rule,
                ),
                const SizedBox(height: 6),
                Text(labels[s]!,
                    style: OndaText.cuerpo(12,
                        weight: s == active ? 600 : 400, color: s == active ? Palette.ink : Palette.inkFaint)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
