import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/rewards_state.dart';

/// Wordmark plus the user's streak, points and progress to the next level.
/// Always visible: the rewards are part of the experience.
class TopBar extends ConsumerWidget {
  const TopBar({super.key, this.trailing});
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('ONDA', style: OndaText.impacto(26, color: Palette.lime)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Align(alignment: Alignment.centerRight, child: trailing ?? const SizedBox.shrink()),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Chip(
                        icon: Icons.local_fire_department_rounded,
                        value: rewards.streakDays,
                        tooltip: 'Días seguidos',
                      ),
                      const SizedBox(width: 8),
                      _Chip(icon: Icons.bolt_rounded, value: rewards.points, tooltip: 'Puntos'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('NIVEL ${rewards.level}', style: OndaText.etiqueta(color: Palette.gold, size: 10)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: rewards.levelProgress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: Palette.line,
                      color: Palette.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('+${rewards.toNextLevel}', style: OndaText.etiqueta(color: Palette.textFaint, size: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.value, required this.tooltip});
  final IconData icon;
  final int value;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
        decoration: BoxDecoration(
          color: Palette.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Palette.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Palette.gold),
            const SizedBox(width: 4),
            // Counter rolls up when points arrive.
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) =>
                  Text('${v.round()}', style: OndaText.cifra(16, color: Palette.gold)),
            ),
          ],
        ),
      ),
    );
  }
}
