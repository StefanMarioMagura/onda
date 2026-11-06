import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/main.dart';
import 'package:onda/state/speech.dart';
import 'package:onda/state/votes_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what would be read aloud instead of calling the platform TTS.
class FakeSpeech implements Speech {
  final spoken = <String>[];
  VoidCallback? _onDone;

  @override
  Future<void> speak(String text, {VoidCallback? onDone}) async {
    spoken.add(text);
    _onDone = onDone;
  }

  void finish() => _onDone?.call();

  @override
  Future<void> stop() async {}
}

Future<FakeSpeech> pumpApp(WidgetTester tester, {Map<String, Object> stored = const {}}) async {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone-sized
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final speech = FakeSpeech();
  await tester.pumpWidget(ProviderScope(
    overrides: [speechProvider.overrideWithValue(speech), prefsProvider.overrideWithValue(await testPrefs(stored))],
    child: const OndaApp(),
  ));
  await tester.pumpAndSettle();
  return speech;
}

/// Taps the right side of the current card (story-style "next").
Future<void> tapForward(WidgetTester tester, {bool settle = true}) async {
  // On the headline: away from buttons ("Las dos orillas") and the side rail.
  await tester.tapAt(const Offset(250, 250));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // First frame starts the animations; the second lets them run to the end.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }
}

/// Empty in-memory device storage for tests.
Future<SharedPreferences> testPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}
