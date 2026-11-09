import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rewards.dart';
import 'votes_state.dart';

/// The user's real points and streak, stored on this device. Everyone starts at
/// zero: no invented numbers (CLAUDE.md).
class RewardsNotifier extends Notifier<Rewards> {
  static const _key = 'rewards_v1';

  @override
  Rewards build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    final saved = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    final now = DateTime.now();
    final rewards = Rewards(
      points: saved?['points'] as int? ?? 0,
      streakDays: streakAfterVisit(
        lastVisit: saved == null ? null : DateTime.tryParse(saved['lastVisit'] as String? ?? ''),
        streak: saved?['streak'] as int? ?? 0,
        today: now,
      ),
      claimed: {...?(saved?['claimed'] as List?)?.cast<String>()},
    );
    _save(rewards, now);
    return rewards;
  }

  /// Gives [amount] for [key] once. Returns true if it was new (to celebrate it).
  bool claim(String key, int amount) {
    if (state.hasClaimed(key)) return false;
    state = state.claim(key, amount);
    _save(state, DateTime.now());
    return true;
  }

  void _save(Rewards r, DateTime now) => ref.read(prefsProvider).setString(_key, jsonEncode({
        'points': r.points,
        'streak': r.streakDays,
        'lastVisit': now.toIso8601String(),
        'claimed': r.claimed.toList(),
      }));
}

final rewardsProvider = NotifierProvider<RewardsNotifier, Rewards>(RewardsNotifier.new);
