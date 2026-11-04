import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/sample_data.dart';
import '../../domain/format.dart';

/// The closing screen. Finishing is the reward: nothing else to scroll.
class EndOfFeed extends ConsumerWidget {
  const EndOfFeed({super.key, required this.wavesRead});
  final int wavesRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saving = ref.watch(monthlySavingProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOY', style: OndaText.antetitulo()),
          const SizedBox(height: 10),
          Text('Ya estás al día.', style: OndaText.titular(44)),
          const SizedBox(height: 14),
          Text('Has leído las $wavesRead ondas de hoy. No hay más: las siguientes llegan mañana a las 8:00.',
              style: OndaText.cuerpo(17, color: Palette.inkSoft)),
          const SizedBox(height: 32),
          const Divider(color: Palette.ink, thickness: 1.5, height: 1.5),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _Stat(value: '$wavesRead', label: 'ondas leídas')),
                const VerticalDivider(color: Palette.rule, width: 1),
                const Expanded(child: _Stat(value: '4 min', label: 'de lectura', leftPad: true)),
              ],
            ),
          ),
          const Divider(),
          _Stat(value: euros(saving), label: 'ahorrados este mes siguiendo el semáforo', big: true),
          const Divider(),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/bolsillo'),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.ink,
                foregroundColor: Palette.paper,
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: Text('¿Lleno hoy o espero?', style: OndaText.cuerpo(16, weight: 600, color: Palette.paper)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.big = false, this.leftPad = false});
  final String value;
  final String label;
  final bool big;
  final bool leftPad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(leftPad ? 16 : 0, 18, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: OndaText.cifra(big ? 48 : 36, color: big ? Capa.bolsillo.color : Palette.ink)),
          const SizedBox(height: 6),
          Text(label, style: OndaText.cuerpo(13, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}
