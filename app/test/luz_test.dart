import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/luz_repository.dart';

void main() {
  final rows = [
    {'hour': '2026-11-06T13:00:00+00:00', 'pvpc_eur_mwh': 160.0},
    {'hour': '2026-11-06T12:00:00+00:00', 'pvpc_eur_mwh': 170.5},
    {'hour': '2026-11-06T19:00:00+00:00', 'pvpc_eur_mwh': 401.79},
  ];
  final day = LuzDay.fromRows(rows);

  test('converts €/MWh to €/kWh and sorts by hour', () {
    final prices = day.hours.map((h) => h.$2).toList();
    expect(prices[0], closeTo(0.1705, 1e-9));
    expect(prices[1], closeTo(0.16, 1e-9));
    expect(prices[2], closeTo(0.40179, 1e-9));
  });

  test('cheapest, priciest and average', () {
    expect(day.cheapest.$2, closeTo(0.16, 1e-9));
    expect(day.priciest.$2, closeTo(0.40179, 1e-9));
    expect(day.average, closeTo((0.1705 + 0.16 + 0.40179) / 3, 1e-9));
  });

  test('price of the hour that contains a moment', () {
    final start = day.hours[1].$1;
    expect(day.priceAt(start.add(const Duration(minutes: 59))), closeTo(0.16, 1e-9));
    expect(day.priceAt(start.subtract(const Duration(days: 1))), isNull);
  });
}
