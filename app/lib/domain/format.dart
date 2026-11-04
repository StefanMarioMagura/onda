/// Spanish number formatting (decimal comma) without pulling in intl.
String _decimal(double value, int decimals) => value.toStringAsFixed(decimals).replaceAll('.', ',');

/// 4.2 -> "4,20 €"
String euros(double value) => '${_decimal(value, 2)} €';

/// 1.512 -> "1,512" (fuel prices always have 3 decimals in Spain)
String fuelPrice(double value) => _decimal(value, 3);

/// 0.024 -> "+2,4 cént.", -0.003 -> "−0,3 cént." (signed: false -> "2,4 cént.")
String cents(double eur, {bool signed = true}) {
  final c = eur * 100;
  final sign = !signed ? '' : (c > 0.05 ? '+' : (c < -0.05 ? '−' : ''));
  return '$sign${_decimal(c.abs(), 1)} cént.';
}

/// 1.8 -> "1,8 km"
String km(double value) => '${_decimal(value, 1)} km';
