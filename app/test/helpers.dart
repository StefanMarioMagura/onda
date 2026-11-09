import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/app/router.dart';
import 'package:onda/data/news_repository.dart';
import 'package:onda/features/shared/links.dart';
import 'package:onda/main.dart';
import 'package:onda/state/speech.dart';
import 'package:onda/state/votes_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what would be read aloud instead of calling the platform TTS.
class FakeSpeech implements Speech {
  FakeSpeech({this.available = true});
  final bool available;
  final spoken = <String>[];
  VoidCallback? _onDone;

  @override
  Future<void> speak(String text, {VoidCallback? onDone}) async {
    if (!available) throw Exception('No voice on this device');
    spoken.add(text);
    _onDone = onDone;
  }

  void finish() => _onDone?.call();

  @override
  Future<void> stop() async {}
}

/// Records the links the app would open in the browser.
class FakeLinks implements LinkOpener {
  FakeLinks({this.works = true});
  final bool works;
  final opened = <String>[];

  @override
  Future<bool> open(String url) async {
    if (works) opened.add(url);
    return works;
  }
}

class TestApp {
  TestApp(this.speech, this.links);
  final FakeSpeech speech;
  final FakeLinks links;
}

Future<TestApp> pumpApp(
  WidgetTester tester, {
  Map<String, Object> stored = const {},
  FakeSpeech? speech,
  FakeLinks? links,
  NewsRepository? news,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3; // phone-sized at 3x
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final app = TestApp(speech ?? FakeSpeech(), links ?? FakeLinks());
  router.go('/hoy'); // the router is global: don't inherit the previous test's screen
  await tester.pumpWidget(ProviderScope(
    overrides: [
      speechProvider.overrideWithValue(app.speech),
      linkOpenerProvider.overrideWithValue(app.links),
      prefsProvider.overrideWithValue(await testPrefs(stored)),
      newsRepositoryProvider.overrideWithValue(news ?? SampleNewsRepository()),
    ],
    child: const OndaApp(),
  ));
  await tester.pumpAndSettle();
  return app;
}

/// Swipes up to the next page of the feed. Doesn't settle: some pages animate forever.
Future<void> swipeToNext(WidgetTester tester) async {
  await tester.drag(find.byType(PageView).first, const Offset(0, -700));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

/// Empty in-memory device storage for tests.
Future<SharedPreferences> testPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}
