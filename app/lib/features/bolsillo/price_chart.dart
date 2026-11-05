import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/format.dart';

/// Line chart of daily prices: lime line with a soft fill, min/max labels.
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
    final h = size.height - 6;
    Offset at(int i) => Offset(i / (values.length - 1) * w, 3 + h - (values[i] - lo) / span * h);

    for (final (y, v) in [(3.0, hi), (3 + h, lo)]) {
      final text = TextPainter(
        text: TextSpan(text: fuelPrice(v), style: OndaText.cuerpo(10, color: Palette.textFaint)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(w + 8, y - text.height / 2));
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.lime.withValues(alpha: 0.22), Palette.lime.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, w, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = Palette.lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    final last = at(values.length - 1);
    canvas.drawCircle(last, 9, Paint()..color = Palette.lime.withValues(alpha: 0.25));
    canvas.drawCircle(last, 4.5, Paint()..color = Palette.lime);
  }

  @override
  bool shouldRepaint(_PricePainter old) => old.values != values;
}
