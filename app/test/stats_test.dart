import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/stats_repository.dart';
import 'package:onda/domain/format.dart';
import 'package:onda/features/espana/espana_screen.dart';

import 'helpers.dart';

// Shape of real indicadores rows from Supabase (INE values of 2026-11-06).
final rows = [
  {'serie': 'salario_medio', 'periodo': '2024-01-01', 'valor': 29540.26},
  {'serie': 'salario_medio', 'periodo': '2023-01-01', 'valor': 28049.94},
  {'serie': 'salario_mediana', 'periodo': '2024-01-01', 'valor': 24497.17},
  {'serie': 'ipc_alimentos_anual', 'periodo': '2026-09-01', 'valor': 2.7},
  {'serie': 'ipc_alimentos_anual', 'periodo': '2026-08-01', 'valor': 2.3},
  {'serie': 'ipc_general_anual', 'periodo': '2026-10-01', 'valor': 4.9},
  {'serie': 'otra_serie', 'periodo': '2026-10-01', 'valor': 1.0},
];

void main() {
  final stats = SpainStats.fromRows(rows);

  test('splits rows by series and sorts them by period', () {
    expect(stats.salaryMean.map((p) => p.period.year), [2023, 2024]);
    expect(stats.foodCpi.map((p) => p.value), [2.3, 2.7]);
    expect(stats.generalCpi.single.value, 4.9);
    expect(stats.salaryMedian.single.value, 24497.17);
  });

  test('salary change against the previous year', () {
    expect(stats.salaryChangePct, closeTo(5.313, 0.001));
    expect(SpainStats.fromRows(rows.take(1).toList()).salaryChangePct, isNull);
  });

  test('what 100 € of food a year ago costs now', () {
    expect(stats.basketToday(100), closeTo(102.70, 1e-9));
  });

  group('Spanish formats', () {
    test('whole euros with thousands dot', () {
      expect(eurosWhole(29540.26), '29.540$nbsp€');
      expect(eurosWhole(950), '950$nbsp€');
      expect(eurosWhole(1234567.8), '1.234.568$nbsp€');
    });
    test('signed percent', () {
      expect(percentSigned(2.7), '+2,7 %');
      expect(percentSigned(-0.4), '−0,4 %');
      expect(percentSigned(0), '0,0 %');
    });
    test('month and year', () => expect(monthYear(DateTime(2026, 9)), 'septiembre de 2026'));
  });

  testWidgets('Tu España shows the shopping basket and salary cards', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Tu España'));
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(EspanaScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('+2,7 %'), 200, scrollable: list);
    expect(find.textContaining('102,70 €', findRichText: true), findsOneWidget);
    await tester.scrollUntilVisible(find.text('24.497$nbsp€'), 200, scrollable: list);
    expect(find.text('29.540$nbsp€'), findsOneWidget);
    expect(find.text('24.497$nbsp€'), findsOneWidget);
    expect(find.text('+5,3 % frente a 2023'), findsOneWidget);
    expect(find.text('PRÓXIMAMENTE'), findsNothing);
  });
}
