import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/app/theme.dart';
import 'package:onda/data/sample_data.dart';
import 'package:onda/domain/discover.dart';
import 'package:onda/domain/fuel.dart';

void main() {
  final container = ProviderContainer();
  final waves = container.read(todayWavesProvider);

  test('today has 5 to 8 ondas before Descubre starts', () {
    expect(waves.length, inInclusiveRange(5, 8));
  });

  test('every onda has exactly 4 cards', () {
    for (final wave in waves) {
      expect(wave.cards.length, 4, reason: wave.id);
    }
  });

  test('only the last card has actions, and it has no teaser', () {
    for (final wave in waves) {
      expect(wave.cards.last.actions, isNotEmpty, reason: wave.id);
      expect(wave.cards.last.teaser, isNull, reason: wave.id);
      expect(wave.cards.take(3).every((c) => c.actions.isEmpty), isTrue, reason: wave.id);
    }
  });

  test('"Las dos orillas" only on Tu país ondas', () {
    for (final wave in waves.where((w) => w.shores != null)) {
      expect(wave.layer, Capa.pais, reason: wave.id);
    }
  });

  test('pocket average price matches the last day of the series', () {
    for (final fuel in Fuel.values) {
      final pocket = samplePocket(fuel);
      expect(pocket.last30Days, hasLength(30));
      expect(pocket.averagePrice, closeTo(pocket.last30Days.last, 1e-9));
    }
  });

  test('Descubre mixes every format and its quizzes are well formed', () {
    final pool = container.read(discoverPoolProvider);
    expect(pool.map((i) => i.runtimeType).toSet(),
        {StoryItem, ClipItem, QuizItem, PredictionItem, FactItem});
    expect(pool.map((i) => i.id).toSet().length, pool.length, reason: 'ids must be unique');
    for (final quiz in pool.whereType<QuizItem>()) {
      expect(quiz.correct, inInclusiveRange(0, quiz.options.length - 1), reason: quiz.id);
    }
  });
}
