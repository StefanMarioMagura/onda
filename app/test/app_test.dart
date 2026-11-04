import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/main.dart';

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);   // iPhone-sized
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: OndaApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('feed opens on the first onda and a tap moves to the next card', (tester) async {
    await pumpApp(tester);
    expect(find.text('El petróleo sube un 6 % en dos semanas'), findsOneWidget);
    expect(find.text('1 de 5'), findsOneWidget);

    await tester.tapAt(const Offset(300, 500));          // right side: forward
    await tester.pumpAndSettle();
    expect(find.textContaining('llega al surtidor'), findsOneWidget);
  });

  testWidgets('tapping past the 4th card jumps to the next onda', (tester) async {
    await pumpApp(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tapAt(const Offset(300, 500));
      await tester.pumpAndSettle();
    }
    expect(find.text('2 de 5'), findsOneWidget);
    expect(find.text('El salario mínimo sube 50 euros al mes'), findsOneWidget);
  });

  testWidgets('Tu bolsillo shows the semáforo and switches fuel', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Tu bolsillo'));
    await tester.pumpAndSettle();
    expect(find.text('Llena hoy'), findsOneWidget);

    await tester.tap(find.text('Gasolina 95'));
    await tester.pumpAndSettle();
    expect(find.text('Da igual'), findsWidgets);        // verdict + scale label
  });
}
