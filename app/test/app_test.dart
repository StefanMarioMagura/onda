import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/sample_data.dart';
import 'package:onda/domain/discover.dart';
import 'package:onda/state/rewards_state.dart';

import 'helpers.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

void main() {
  testWidgets('feed opens on the first onda and a tap moves to the next card', (tester) async {
    await pumpApp(tester);
    expect(find.text('El petróleo sube un 6 % en dos semanas'), findsOneWidget);
    expect(find.text('HOY 1/5'), findsOneWidget);

    await tapForward(tester);
    expect(find.textContaining('llega al surtidor'), findsOneWidget);
  });

  testWidgets('completing an onda gives points once and opens the next onda', (tester) async {
    await pumpApp(tester);
    final before = containerOf(tester).read(rewardsProvider).points;
    for (var i = 0; i < 4; i++) {
      await tapForward(tester);
    }
    expect(find.text('HOY 2/5'), findsOneWidget);
    expect(containerOf(tester).read(rewardsProvider).points, before + 10);
  });

  testWidgets('after the last onda comes the milestone, and the feed keeps going', (tester) async {
    await pumpApp(tester);
    for (var i = 0; i < 19; i++) {
      await tapForward(tester);
    }
    await tapForward(tester, settle: false); // milestone animates forever: no settle
    expect(find.text('COMPLETADO'), findsOneWidget);
    expect(find.text('DESCUBRE'), findsOneWidget);
    // 5 ondas x 10 + 50 for the day.
    expect(containerOf(tester).read(rewardsProvider).points, 80 + 50 + 50);

    await tester.drag(find.byType(PageView).first, const Offset(0, -700));
    await tester.pump(const Duration(seconds: 2));
    final pool = containerOf(tester).read(discoverPoolProvider);
    final first = discoverAt(pool, 0).item;
    expect(find.text('DESCUBRE · ${first.topic.toUpperCase()}'), findsOneWidget);
  });

  testWidgets('listen reads the card aloud', (tester) async {
    final speech = await pumpApp(tester);
    await tester.tap(find.text('Escuchar').first);
    await tester.pump();
    expect(speech.spoken.single, startsWith('El petróleo sube un 6 % en dos semanas.'));
    expect(find.text('Parar'), findsOneWidget);
    speech.finish();
    await tester.pump();
    expect(find.text('Escuchar'), findsWidgets);
  });

  testWidgets('Tu bolsillo shows the semáforo and switches fuel', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Tu bolsillo'));
    await tester.pumpAndSettle();
    expect(find.text('LLENA HOY'), findsOneWidget);

    await tester.tap(find.text('GASOLINA 95'));
    await tester.pumpAndSettle();
    expect(find.text('DA IGUAL'), findsOneWidget);
  });
}
