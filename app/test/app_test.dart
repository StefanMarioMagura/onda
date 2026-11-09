import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/discover_content.dart';
import 'package:onda/data/news_repository.dart';
import 'package:onda/data/sample_data.dart';
import 'package:onda/domain/discover.dart';
import 'package:onda/domain/news.dart';
import 'package:onda/state/rewards_state.dart';

import 'helpers.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

/// A repository whose network can be switched on and off.
class FlakyNews implements NewsRepository {
  FlakyNews({this.online = false, this.topics = sampleTopics});
  bool online;
  final List<NewsTopic> topics;

  @override
  Future<TodayNews> load() async {
    if (!online) throw Exception('network down');
    return TodayNews(topics: topics, latest: sampleLatest);
  }
}

void main() {
  final first = sampleTopics[0];

  testWidgets('a new user starts with real numbers: no invented points or streak', (tester) async {
    await pumpApp(tester);
    expect(containerOf(tester).read(rewardsProvider).points, 0);
    expect(containerOf(tester).read(rewardsProvider).streakDays, 1);
  });

  testWidgets('the feed opens on the first topic with its headline, extract and coverage', (tester) async {
    await pumpApp(tester);
    expect(find.text(first.headline), findsOneWidget);
    expect(find.text(first.summary!), findsOneWidget);
    expect(find.text('3 MEDIOS'), findsOneWidget);
    expect(find.text('HOY 1/2'), findsOneWidget);
    expect(find.text('CONTENIDO DE EJEMPLO'), findsOneWidget);
  });

  testWidgets('real data has no sample label', (tester) async {
    await pumpApp(tester, news: FlakyNews(online: true));
    expect(find.text('CONTENIDO DE EJEMPLO'), findsNothing);
  });

  testWidgets('reading opens the outlet in the browser and gives points once', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('LEER EN MEDIO A'));
    await tester.pumpAndSettle();
    expect(app.links.opened, [first.url]);
    expect(containerOf(tester).read(rewardsProvider).points, 10);

    await tester.tap(find.text('LEER EN MEDIO A'));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(rewardsProvider).points, 10);
  });

  testWidgets('if the link fails it says so and gives no points', (tester) async {
    await pumpApp(tester, links: FakeLinks(works: false));
    await tester.tap(find.text('LEER EN MEDIO A'));
    await tester.pumpAndSettle();
    expect(find.text('No hemos podido abrir la noticia.'), findsOneWidget);
    expect(containerOf(tester).read(rewardsProvider).points, 0);
  });

  testWidgets('Las dos orillas shows each side\'s real headlines, and they open', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('LAS DOS ORILLAS'));
    await tester.pumpAndSettle();
    expect(find.text('IZQUIERDA'), findsOneWidget);
    expect(find.text('DERECHA'), findsOneWidget);
    for (final h in first.headlines) {
      expect(find.text(h.title), findsOneWidget);
    }
    await tester.tap(find.text('La oposición critica la medida de ejemplo'));
    await tester.pumpAndSettle();
    expect(app.links.opened, ['https://example.com/derecha']);
  });

  testWidgets('a topic not covered by both sides is not called "dos orillas"', (tester) async {
    await pumpApp(tester);
    await swipeToNext(tester);
    expect(find.text('HOY 2/2'), findsOneWidget);
    expect(find.text('CÓMO LO CUENTAN'), findsOneWidget);
    expect(find.text('LAS DOS ORILLAS'), findsNothing);
  });

  testWidgets('after the topics comes the milestone, and the feed keeps going', (tester) async {
    await pumpApp(tester);
    await swipeToNext(tester);
    await swipeToNext(tester);
    expect(find.text('COMPLETADO'), findsOneWidget);
    expect(containerOf(tester).read(rewardsProvider).points, 50);

    await swipeToNext(tester);
    expect(find.text('DESCUBRE'), findsOneWidget);
    final pool = [...discoverContent, ...sampleLatest];
    expect(find.text('DESCUBRE · ${discoverAt(pool, 0).item.topic.toUpperCase()}'), findsOneWidget);
  });

  testWidgets('with no topics today it goes straight to Descubre, without a free milestone', (tester) async {
    await pumpApp(tester, news: FlakyNews(online: true, topics: const []));
    expect(find.text('DESCUBRE'), findsOneWidget);
    expect(find.text('COMPLETADO'), findsNothing);
    expect(containerOf(tester).read(rewardsProvider).points, 0);
  });

  testWidgets('without network it shows an error, and Reintentar recovers', (tester) async {
    final news = FlakyNews();
    await pumpApp(tester, news: news);
    await tester.pump(const Duration(seconds: 3));   // automatic retries run out
    await tester.pumpAndSettle();
    expect(find.text('NO HEMOS PODIDO CARGAR LAS NOTICIAS'), findsOneWidget);

    news.online = true;
    await tester.tap(find.text('REINTENTAR'));
    await tester.pumpAndSettle();
    expect(find.text(first.headline), findsOneWidget);
  });

  testWidgets('on a small screen a long page scrolls, and dragging past its end turns the page', (tester) async {
    await pumpApp(tester, size: const Size(320, 480));
    expect(tester.takeException(), isNull);
    expect(find.text('HOY 1/2'), findsOneWidget);
    for (var i = 0; i < 4 && find.text('HOY 2/2').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(PageView).first, const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('HOY 2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('listen reads the news aloud', (tester) async {
    final app = await pumpApp(tester);
    await tester.tap(find.text('Escuchar').first);
    await tester.pump();
    expect(app.speech.spoken.single, startsWith(first.headline));
    expect(find.text('Parar'), findsOneWidget);
    app.speech.finish();
    await tester.pump();
    expect(find.text('Escuchar'), findsWidgets);
  });

  testWidgets('a device without a voice gets a message, not a crash', (tester) async {
    await pumpApp(tester, speech: FakeSpeech(available: false));
    await tester.tap(find.text('Escuchar').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('no está disponible'), findsOneWidget);
    expect(find.text('Parar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tu España opens the fuel detail with the semáforo, and switches fuel', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Tu España'));
    await tester.pumpAndSettle();
    expect(find.text('LUZ HOY · TARIFA REGULADA (PVPC)'), findsOneWidget);
    await tester.tap(find.text('CARBURANTES'));
    await tester.pumpAndSettle();
    expect(find.text('LLENA HOY'), findsOneWidget);

    await tester.tap(find.text('GASOLINA 95'));
    await tester.pumpAndSettle();
    expect(find.text('DA IGUAL'), findsOneWidget);
  });

  testWidgets('a wide PC window keeps the feed as a column', (tester) async {
    await pumpApp(tester, size: const Size(1280, 800));
    expect(tester.getSize(find.byType(PageView).first).width, lessThanOrEqualTo(560));
    expect(tester.takeException(), isNull);
  });
}
