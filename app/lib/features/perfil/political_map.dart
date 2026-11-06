import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/affinity.dart';

/// Economy (x) × society (y) compass with every party and the user.
class Compass extends StatelessWidget {
  const Compass({super.key, required this.parties, required this.user, this.highlight});
  final List<Party> parties;
  final Offset user; // (economía, sociedad), 0-10
  final Party? highlight;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(painter: _CompassPainter(parties, user, highlight)),
    );
  }
}

/// Parties with at least this many seats get a label on the compass.
const labelledSeats = 20;

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.parties, this.user, this.highlight);
  final List<Party> parties;
  final Offset user;
  final Party? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 22.0;
    final area = Rect.fromLTWH(pad, pad, size.width - 2 * pad, size.height - 2 * pad);
    // 0-10 to canvas, inside an inner margin so extreme points stay in the box;
    // "conservador" (10) at the top.
    final plot = area.deflate(18);
    Offset at(double eco, double soc) =>
        Offset(plot.left + eco / 10 * plot.width, plot.bottom - soc / 10 * plot.height);

    final rect = RRect.fromRectAndRadius(area, const Radius.circular(12));
    canvas.drawRRect(rect, Paint()..color = Palette.surface);
    final line = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(area.center.dx, area.top), Offset(area.center.dx, area.bottom), line);
    canvas.drawLine(Offset(area.left, area.center.dy), Offset(area.right, area.center.dy), line);

    void label(String text, Offset pos, {TextAlign align = TextAlign.center, Color color = Palette.textFaint}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: OndaText.etiqueta(size: 9, color: color)),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    label('CONSERVADOR', Offset(area.center.dx, pad / 2));
    label('PROGRESISTA', Offset(area.center.dx, size.height - pad / 2));
    label('IZQ.', Offset(pad / 2 + 2, area.center.dy));
    label('DER.', Offset(size.width - pad / 2 - 2, area.center.dy));

    // Small parties cluster together: only large ones and the top match get a
    // label (the full list with names is shown under the compass).
    for (final p in parties) {
      final pos = at(p.position[PolAxis.economia]!, p.position[PolAxis.sociedad]!);
      final isTop = p.id == highlight?.id;
      canvas.drawCircle(pos, isTop ? 6 : 3.5, Paint()..color = isTop ? Palette.gold : Palette.textFaint);
      if (isTop || p.seats >= labelledSeats) {
        label(p.short, pos + const Offset(0, -12), color: isTop ? Palette.gold : Palette.textSoft);
      }
    }

    final me = at(user.dx, user.dy);
    canvas.drawCircle(me, 14, Paint()..color = Palette.lime.withValues(alpha: 0.25));
    canvas.drawCircle(me, 7, Paint()..color = Palette.lime);
    // "TÚ" goes on the side with room.
    label('TÚ', me + Offset(0, me.dy > plot.center.dy ? -20 : 20), color: Palette.lime);
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.user != user || old.highlight != highlight;
}

/// One axis as a 0-10 bar: party ticks and the user's marker.
class AxisBar extends StatelessWidget {
  const AxisBar({super.key, required this.axis, required this.value, required this.parties, required this.votes});
  final PolAxis axis;
  final double? value;
  final List<Party> parties;
  final int votes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(axis.label.toUpperCase(), style: OndaText.etiqueta(size: 11, color: Palette.text)),
            const Spacer(),
            Text(value == null ? '$votes/$minVotesPerAxis valoraciones' : value!.toStringAsFixed(1).replaceAll('.', ','),
                style: OndaText.etiqueta(size: 11, color: value == null ? Palette.textFaint : Palette.lime)),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            height: 22,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(color: Palette.line, borderRadius: BorderRadius.circular(2)),
                ),
                for (final p in parties)
                  Positioned(
                    left: p.position[axis]! / 10 * (c.maxWidth - 2),
                    child: Container(width: 2, height: 12, color: Palette.textFaint),
                  ),
                if (value != null)
                  Positioned(
                    left: value! / 10 * (c.maxWidth - 16),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Palette.lime,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Palette.lime.withValues(alpha: 0.5), blurRadius: 10)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(axis.low, style: OndaText.cuerpo(11, color: Palette.textFaint)),
            const Spacer(),
            Text(axis.high, style: OndaText.cuerpo(11, color: Palette.textFaint)),
          ],
        ),
      ],
    );
  }
}
