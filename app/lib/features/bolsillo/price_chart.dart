import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/format.dart';

/// Minimal line chart of daily prices: the line, the last point, and the
/// min/max as hairline references. No grid, no axes chrome.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PricePainter(values), size: Size.infinite);
}

class _PricePainter extends CustomPainter {
  _PricePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    const labelSpace = 44.0;
    final w = size.width - labelSpace;
    Offset at(int i) => Offset(i / (values.length - 1) * w, size.height - (values[i] - lo) / span * size.height);

    final rule = Paint()
      ..color = Palette.rule
      ..strokeWidth = 1;
    for (final (y, v) in [(0.0, hi), (size.height, lo)]) {
      canvas.drawLine(Offset(0, y), Offset(w, y), rule);
      final text = TextPainter(
        text: TextSpan(text: fuelPrice(v), style: OndaText.cuerpo(10, color: Palette.inkFaint)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(w + 8, y - text.height / 2));
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Palette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(values.length - 1), 4, Paint()..color = Palette.ink);
  }

  @override
  bool shouldRepaint(_PricePainter old) => old.values != values;
}
