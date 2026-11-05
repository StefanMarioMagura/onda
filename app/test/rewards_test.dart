import 'package:flutter_test/flutter_test.dart';
import 'package:onda/domain/discover.dart';
import 'package:onda/domain/rewards.dart';

void main() {
  group('Rewards', () {
    const start = Rewards(points: 80, streakDays: 5);

    test('levels every 100 points', () {
      expect(start.level, 1);
      expect(start.toNextLevel, 20);
      expect(start.levelProgress, closeTo(0.8, 1e-9));
      expect(start.claim('x', 20).level, 2);
    });

    test('a reward key pays only once', () {
      final once = start.claim('wave:brent', 10);
      expect(once.points, 90);
      expect(once.claim('wave:brent', 10).points, 90);
    });

    test('spending cannot go below zero', () {
      expect(start.spend(80).points, 0);
      expect(() => start.spend(81), throwsStateError);
    });
  });

  group('streakAfterVisit', () {
    final today = DateTime(2026, 11, 5, 9);
    test('first visit starts at 1', () => expect(streakAfterVisit(lastVisit: null, streak: 0, today: today), 1));
    test('same day keeps it', () {
      expect(streakAfterVisit(lastVisit: DateTime(2026, 11, 5, 0, 5), streak: 5, today: today), 5);
    });
    test('next day adds one, even across midnight by minutes', () {
      expect(streakAfterVisit(lastVisit: DateTime(2026, 11, 4, 23, 59), streak: 5, today: today), 6);
    });
    test('missing a day resets to 1', () {
      expect(streakAfterVisit(lastVisit: DateTime(2026, 11, 3), streak: 5, today: today), 1);
    });
  });

  group('Prediction', () {
    test('right guess pays double the stake', () {
      expect(const Prediction(stake: 20, saidYes: true).payout(happened: true), 40);
      expect(const Prediction(stake: 20, saidYes: false).payout(happened: false), 40);
    });
    test('wrong guess pays nothing', () {
      expect(const Prediction(stake: 20, saidYes: true).payout(happened: false), 0);
    });
  });

  group('discoverAt (endless stream)', () {
    final pool = [
      for (var i = 0; i < 5; i++) FactItem(id: 'f$i', topic: 't', figure: '$i', text: '', source: ''),
    ];

    test('never ends and keys stay unique', () {
      final keys = [for (var i = 0; i < 200; i++) discoverAt(pool, i).key];
      expect(keys.toSet().length, 200);
    });

    test('each pass shows every item exactly once', () {
      for (var round = 0; round < 10; round++) {
        final ids = {for (var i = 0; i < 5; i++) discoverAt(pool, round * 5 + i).item.id};
        expect(ids.length, 5);
      }
    });

    test('never repeats the same item back to back between passes', () {
      for (var i = 1; i < 500; i++) {
        expect(discoverAt(pool, i).item.id, isNot(discoverAt(pool, i - 1).item.id), reason: 'index $i');
      }
    });

    test('is reproducible', () {
      expect(discoverAt(pool, 37).key, discoverAt(pool, 37).key);
    });
  });
}
