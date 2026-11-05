import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads text aloud. An interface so widget tests can use a fake instead of
/// the platform text-to-speech engine.
abstract class Speech {
  Future<void> speak(String text, {VoidCallback? onDone});
  Future<void> stop();
}

class DeviceSpeech implements Speech {
  DeviceSpeech() {
    _tts.setLanguage('es-ES');
    _tts.setSpeechRate(0.5);
  }

  final _tts = FlutterTts();

  @override
  Future<void> speak(String text, {VoidCallback? onDone}) async {
    _tts.setCompletionHandler(() => onDone?.call());
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}

final speechProvider = Provider<Speech>((ref) => DeviceSpeech());
