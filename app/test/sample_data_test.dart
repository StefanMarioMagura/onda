import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/discover_content.dart';
import 'package:onda/data/sample_data.dart';
import 'package:onda/domain/discover.dart';
import 'package:onda/domain/fuel.dart';
import 'package:onda/domain/news.dart';

void main() {
  test('Descubre\'s own content mixes every format and its quizzes are well formed', () {
    expect(discoverContent.map((i) => i.runtimeType).toSet(),
        {StoryItem, ClipItem, QuizItem, FactItem, DebateItem});
    expect(discoverContent.map((i) => i.id).toSet().length, discoverContent.length, reason: 'ids must be unique');
    for (final quiz in discoverContent.whereType<QuizItem>()) {
      expect(quiz.correct, inInclusiveRange(0, quiz.options.length - 1), reason: quiz.id);
    }
  });

  test('every debate is marked for the political map', () {
    final stances = ProviderContainer().read(stancesProvider);
    for (final debate in discoverContent.whereType<DebateItem>()) {
      expect(stances[debate.id], isNotNull, reason: debate.id);
    }
  });

  test('sample topics have valid links and cover the two cases', () {
    expect(sampleTopics.any((t) => t.bothSides), isTrue);
    expect(sampleTopics.any((t) => !t.bothSides), isTrue);
    for (final t in sampleTopics) {
      expect(isWebLink(t.url), isTrue, reason: t.id);
    }
  });

  test('pocket average price matches the last day of the series', () {
    for (final fuel in Fuel.values) {
      final pocket = samplePocket(fuel);
      expect(pocket.last30Days, hasLength(30));
      expect(pocket.averagePrice, closeTo(pocket.last30Days.last, 1e-9));
    }
  });
}
