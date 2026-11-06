import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/app/theme.dart';
import 'package:onda/data/sample_data.dart';
import 'package:onda/domain/discover.dart';
import 'package:onda/features/discover/discover_pages.dart';
import 'package:onda/state/rewards_state.dart';
import 'package:onda/state/speech.dart';
import 'package:onda/state/votes_state.dart';

import 'helpers.dart';

/// Pumps a single Descubre page and returns the container to inspect state.
Future<ProviderContainer> pumpItem(WidgetTester tester, DiscoverItem item) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    speechProvider.overrideWithValue(FakeSpeech()),
    prefsProvider.overrideWithValue(await testPrefs()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: ondaTheme(), home: Scaffold(body: DiscoverPage(item: item))),
  ));
  await tester.pumpAndSettle();
  return container;
}

T poolItem<T extends DiscoverItem>() =>
    ProviderContainer().read(discoverPoolProvider).whereType<T>().first;

void main() {
  testWidgets('right quiz answer gives points once', (tester) async {
    final quiz = poolItem<QuizItem>();
    final container = await pumpItem(tester, quiz);
    final before = container.read(rewardsProvider).points;

    await tester.tap(find.text(quiz.options[quiz.correct]));
    await tester.pumpAndSettle();
    expect(find.text('¡ACERTASTE!'), findsOneWidget);
    expect(container.read(rewardsProvider).points, before + 20);

    await tester.tap(find.text(quiz.options[quiz.correct])); // locked after answering
    await tester.pumpAndSettle();
    expect(container.read(rewardsProvider).points, before + 20);
  });

  testWidgets('wrong quiz answer shows the right one and gives nothing', (tester) async {
    final quiz = poolItem<QuizItem>();
    final container = await pumpItem(tester, quiz);
    final before = container.read(rewardsProvider).points;
    final wrong = quiz.correct == 0 ? 1 : 0;

    await tester.tap(find.text(quiz.options[wrong]));
    await tester.pumpAndSettle();
    expect(find.text('NO ERA ESA'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(container.read(rewardsProvider).points, before);
  });

  testWidgets('a prediction takes the stake and stays pending', (tester) async {
    final prediction = poolItem<PredictionItem>();
    final container = await pumpItem(tester, prediction);
    final before = container.read(rewardsProvider).points;

    await tester.tap(find.text('SÍ'));
    await tester.pumpAndSettle();
    expect(container.read(rewardsProvider).points, before - prediction.stake);
    expect(container.read(predictionsProvider)[prediction.id]!.saidYes, isTrue);
    expect(find.text('TU PRONÓSTICO: SÍ'), findsOneWidget);
  });

  testWidgets('a prediction without enough points is refused', (tester) async {
    final prediction = poolItem<PredictionItem>();
    final container = await pumpItem(tester, prediction);
    container.read(rewardsProvider.notifier).spend(container.read(rewardsProvider).points);

    await tester.tap(find.text('NO'));
    await tester.pump();
    expect(container.read(predictionsProvider), isEmpty);
    expect(find.textContaining('Necesitas'), findsOneWidget);
  });

  testWidgets('a clip moves through its beats and pauses on tap', (tester) async {
    final clip = poolItem<ClipItem>();
    await pumpItem(tester, clip);
    expect(find.text(clip.beats[0]), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
    expect(find.text(clip.beats[1].toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Toca para pausar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text(clip.beats[1].toUpperCase()), findsOneWidget);
  });
}
