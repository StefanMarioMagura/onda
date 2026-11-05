import 'dart:math';

import '../app/theme.dart';

/// Items of the endless "Descubre" stream that follows today's ondas.
/// Formats are mixed on purpose: each swipe can bring something different.
sealed class DiscoverItem {
  const DiscoverItem({required this.id, required this.topic});
  final String id;

  /// Short label shown above the item ("Historia", "Ciencia"...).
  final String topic;
}

/// A short story with optional audio narration.
class StoryItem extends DiscoverItem {
  const StoryItem({required super.id, required super.topic, required this.title, required this.body, this.year});
  final String title;
  final String body;
  final String? year;

  String get narration => '$title. $body';
}

/// A short clip of animated type: each beat is one screen of text.
class ClipItem extends DiscoverItem {
  const ClipItem({required super.id, required super.topic, required this.title, required this.beats});
  final String title;
  final List<String> beats;
}

class QuizItem extends DiscoverItem {
  const QuizItem({
    required super.id,
    required super.topic,
    required this.question,
    required this.options,
    required this.correct,
    required this.explanation,
  });
  final String question;
  final List<String> options;
  final int correct;
  final String explanation;
}

class PredictionItem extends DiscoverItem {
  const PredictionItem({
    required super.id,
    required super.topic,
    required this.question,
    required this.stake,
    required this.resolvesOn,
  });
  final String question;
  final int stake;
  final String resolvesOn;
}

class FactItem extends DiscoverItem {
  const FactItem({required super.id, required super.topic, required this.figure, required this.text, required this.source});
  final String figure;
  final String text;
  final String source;
}

Capa get discoverLayer => Capa.descubre;

/// Item number [index] of an endless stream built from [pool].
/// Each pass over the pool uses a different (but reproducible) order, so the
/// stream never feels like a loop, and ids stay unique across passes.
({DiscoverItem item, String key}) discoverAt(List<DiscoverItem> pool, int index) {
  final round = index ~/ pool.length;
  final order = List<int>.generate(pool.length, (i) => i)..shuffle(Random(round));
  if (round > 0) {
    // Avoid showing the last item of one pass first in the next.
    final previousLast = (List<int>.generate(pool.length, (i) => i)..shuffle(Random(round - 1))).last;
    if (order.first == previousLast && pool.length > 1) {
      final tmp = order[0];
      order[0] = order[1];
      order[1] = tmp;
    }
  }
  final item = pool[order[index % pool.length]];
  return (item: item, key: '${item.id}#$round');
}
