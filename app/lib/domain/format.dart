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

/// Non-breaking space: an amount and its unit never end up on different lines.
const nbsp = '\u00A0';

/// 29540.26 -> "29.540 €" (thousands with a dot, no decimals; non-breaking space).
String eurosWhole(double value) {
  final digits = value.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return '$grouped$nbsp€';
}

/// 2.7 -> "+2,7 %", -0.4 -> "−0,4 %"
String percentSigned(double value) {
  final sign = value > 0 ? '+' : (value < 0 ? '−' : '');
  return '$sign${_decimal(value.abs(), 1)} %';
}

const _monthNames = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
    'septiembre', 'octubre', 'noviembre', 'diciembre'];

/// DateTime(2026, 9) -> "septiembre de 2026"
String monthYear(DateTime d) => '${_monthNames[d.month - 1]} de ${d.year}';
