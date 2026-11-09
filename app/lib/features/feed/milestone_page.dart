import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/rewards.dart';
import '../../state/rewards_state.dart';

/// Shown after the day's topics: the day's reward, then the feed carries on into Descubre.
class MilestonePage extends ConsumerStatefulWidget {
  const MilestonePage({super.key, required this.topicsRead});
  final int topicsRead;

  @override
  ConsumerState<MilestonePage> createState() => _MilestonePageState();
}

class _MilestonePageState extends ConsumerState<MilestonePage> with SingleTickerProviderStateMixin {
  late final _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rewards = ref.watch(rewardsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TEMAS DE HOY', style: OndaText.etiqueta(color: Palette.gold, size: 12)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('COMPLETADO', style: OndaText.impacto(72, color: Palette.text)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _Stat(value: '+${PointsRules.dailyMilestone}', label: 'puntos extra', color: Palette.gold),
              const SizedBox(width: 12),
              _Stat(value: '${rewards.streakDays}', label: 'días seguidos', color: Palette.gold,
                  icon: Icons.local_fire_department_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(value: '${widget.topicsRead}', label: 'temas del día', color: Palette.text),
              const SizedBox(width: 12),
              _Stat(value: '${rewards.points}', label: 'puntos en total', color: Palette.gold),
            ],
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text('SIGUE CON DESCUBRE', style: OndaText.etiqueta(color: Palette.descubre, size: 13)),
                Text('Más noticias, historias, debates y curiosidades', style: OndaText.cuerpo(14, color: Palette.textSoft)),
                AnimatedBuilder(
                  animation: _bounce,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, 6 * Curves.easeInOut.transform(_bounce.value)),
                    child: child,
                  ),
                  child: Icon(Icons.keyboard_double_arrow_down_rounded, size: 36, color: Palette.descubre),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color, this.icon});
  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, color: color, size: 28),
                Flexible(child: Text(value, style: OndaText.cifra(38, color: color))),
              ],
            ),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: OndaText.etiqueta(size: 10)),
          ],
        ),
      ),
    );
  }
}
