import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads text aloud. An interface so widget tests can use a fake instead of
/// the platform text-to-speech engine.
abstract class Speech {
  Future<void> speak(String text, {VoidCallback? onDone});
  Future<void> stop();
}

/// flutter_tts has no voice on some platforms (Linux desktop): [speak] then
/// throws and the UI tells the user, instead of an uncaught error.
class DeviceSpeech implements Speech {
  final _tts = FlutterTts();
  bool _configured = false;

  @override
  Future<void> speak(String text, {VoidCallback? onDone}) async {
    if (!_configured) {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.5);
      _configured = true;
    }
    _tts.setCompletionHandler(() => onDone?.call());
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('Speech stop failed: $e');
    }
  }
}

final speechProvider = Provider<Speech>((ref) => DeviceSpeech());
