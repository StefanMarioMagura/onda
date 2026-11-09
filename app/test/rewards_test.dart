import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/domain/discover.dart';
import 'package:onda/domain/rewards.dart';
import 'package:onda/state/rewards_state.dart';
import 'package:onda/state/votes_state.dart';

import 'helpers.dart';

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

  });

  group('RewardsNotifier (real numbers, stored on the device)', () {
    Future<ProviderContainer> container([Map<String, Object> stored = const {}]) async {
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(await testPrefs(stored))]);
      addTearDown(c.dispose);
      return c;
    }

    String saved(int points, int streak, DateTime lastVisit) => jsonEncode(
        {'points': points, 'streak': streak, 'lastVisit': lastVisit.toIso8601String(), 'claimed': ['vote:a']});

    test('a new user starts at zero points and a one-day streak', () async {
      final c = await container();
      expect(c.read(rewardsProvider).points, 0);
      expect(c.read(rewardsProvider).streakDays, 1);
    });

    test('coming back the next day adds to the streak and keeps the points', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final c = await container({'rewards_v1': saved(40, 3, yesterday)});
      expect(c.read(rewardsProvider).points, 40);
      expect(c.read(rewardsProvider).streakDays, 4);
    });

    test('missing days resets the streak, not the points', () async {
      final longAgo = DateTime.now().subtract(const Duration(days: 5));
      final c = await container({'rewards_v1': saved(40, 3, longAgo)});
      expect(c.read(rewardsProvider).streakDays, 1);
      expect(c.read(rewardsProvider).points, 40);
    });

    test('claims survive a restart and never pay twice', () async {
      final c = await container({'rewards_v1': saved(40, 3, DateTime.now())});
      expect(c.read(rewardsProvider.notifier).claim('vote:a', 5), isFalse);
      expect(c.read(rewardsProvider.notifier).claim('vote:b', 5), isTrue);
      final restarted = ProviderContainer(overrides: [prefsProvider.overrideWithValue(c.read(prefsProvider))]);
      addTearDown(restarted.dispose);
      expect(restarted.read(rewardsProvider).points, 45);
      expect(restarted.read(rewardsProvider).hasClaimed('vote:b'), isTrue);
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
