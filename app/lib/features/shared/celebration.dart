import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Big "+N" that pops in the centre and floats away, with a haptic tap.
void celebrate(BuildContext context, int points, {String? label}) {
  HapticFeedback.mediumImpact();
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Burst(points: points, label: label, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Burst extends StatefulWidget {
  const _Burst({required this.points, required this.label, required this.onDone});
  final int points;
  final String? label;
  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final scale = Curves.elasticOut.transform((t * 2.2).clamp(0, 1)) * 1.0;
          final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Brief dark fade so the reward reads clearly over any content.
              ColoredBox(color: Palette.night.withValues(alpha: 0.7 * opacity.clamp(0, 1))),
              Center(
                child: Transform.translate(
                  offset: Offset(0, -80 * Curves.easeIn.transform(t)),
                  child: Opacity(
                    opacity: opacity.clamp(0, 1),
                    child: Transform.scale(
                      scale: 0.4 + 0.6 * scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+${widget.points}',
                            style: OndaText.impacto(96, color: Palette.gold).copyWith(
                              shadows: [Shadow(color: Palette.gold.withValues(alpha: 0.6), blurRadius: 30)],
                            ),
                          ),
                          if (widget.label != null)
                            Text(
                              widget.label!.toUpperCase(),
                              style: OndaText.etiqueta(color: Palette.gold, size: 13),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
