import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/app/theme.dart';
import 'package:onda/domain/affinity.dart';
import 'package:onda/features/shared/vote_dial.dart';
import 'package:onda/state/rewards_state.dart';
import 'package:onda/state/votes_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<ProviderContainer> container([Map<String, Object> stored = const {}]) async {
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(await testPrefs(stored))]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('VotesNotifier', () {
    test('stores votes on the device and returns the previous one', () async {
      final c = await container();
      expect(c.read(votesProvider.notifier).cast('smi', Vote.bien), isNull);
      expect(c.read(votesProvider.notifier).cast('smi', Vote.mal), Vote.bien);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('votes_v1'), '{"smi":"mal"}');
    });

    test('loads stored votes and ignores unknown values', () async {
      final c = await container({'votes_v1': '{"a":"bien","b":"genial"}'});
      expect(c.read(votesProvider), {'a': Vote.bien});
    });

    test('clearAll removes everything', () async {
      final c = await container({'votes_v1': '{"a":"bien"}'});
      c.read(votesProvider.notifier).clearAll();
      expect(c.read(votesProvider), isEmpty);
      expect((await SharedPreferences.getInstance()).getString('votes_v1'), isNull);
    });

    test('political map consent is off by default and persisted', () async {
      final c = await container();
      expect(c.read(politicalMapConsentProvider), isFalse);
      c.read(politicalMapConsentProvider.notifier).set(true);
      expect((await SharedPreferences.getInstance()).getBool('political_map_consent_v1'), isTrue);
    });
  });

  group('VoteDial', () {
    Future<ProviderContainer> pumpDial(WidgetTester tester) async {
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(await testPrefs())]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: ondaTheme(),
          home: const Scaffold(body: Padding(padding: EdgeInsets.all(20), child: VoteDial(itemId: 'smi'))),
        ),
      ));
      return c;
    }

    testWidgets('sliding right votes "bien" and gives points once', (tester) async {
      final c = await pumpDial(tester);
      final before = c.read(rewardsProvider).points;
      await tester.drag(find.byIcon(Icons.swap_horiz_rounded), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(c.read(votesProvider)['smi'], Vote.bien);
      expect(find.text('TU VOTO: BIEN'), findsOneWidget);
      expect(c.read(rewardsProvider).points, before + 5);
      expect(find.textContaining('pocos votos'), findsOneWidget);   // no totals without real votes
    });

    testWidgets('sliding left votes "mal"; a short slide does nothing', (tester) async {
      final c = await pumpDial(tester);
      await tester.drag(find.byIcon(Icons.swap_horiz_rounded), const Offset(-30, 0));
      await tester.pumpAndSettle();
      expect(c.read(votesProvider), isEmpty);
      await tester.drag(find.byIcon(Icons.swap_horiz_rounded), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(c.read(votesProvider)['smi'], Vote.mal);
    });

    testWidgets('tapping the centre votes "me da igual", and the vote can be changed', (tester) async {
      final c = await pumpDial(tester);
      await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
      await tester.pumpAndSettle();
      expect(c.read(votesProvider)['smi'], Vote.igual);
      final points = c.read(rewardsProvider).points;

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      await tester.drag(find.byIcon(Icons.swap_horiz_rounded), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(c.read(votesProvider)['smi'], Vote.bien);
      expect(c.read(rewardsProvider).points, points);               // changing doesn't pay again
    });
  });
}
