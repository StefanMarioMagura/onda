import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rewards.dart';

/// The user's points and streak. In-memory for the prototype; will be stored
/// in Supabase per user.
class RewardsNotifier extends Notifier<Rewards> {
  @override
  Rewards build() => const Rewards(points: 80, streakDays: 5);

  /// Gives [amount] for [key] once. Returns true if it was new (to celebrate it).
  bool claim(String key, int amount) {
    if (state.hasClaimed(key)) return false;
    state = state.claim(key, amount);
    return true;
  }

  bool canAfford(int amount) => state.points >= amount;

  void spend(int amount) => state = state.spend(amount);
}

final rewardsProvider = NotifierProvider<RewardsNotifier, Rewards>(RewardsNotifier.new);

/// Predictions the user has placed, by item id (pending until resolved with real data).
class PredictionsNotifier extends Notifier<Map<String, Prediction>> {
  @override
  Map<String, Prediction> build() => const {};

  void place(String id, Prediction prediction) => state = {...state, id: prediction};
}

final predictionsProvider =
    NotifierProvider<PredictionsNotifier, Map<String, Prediction>>(PredictionsNotifier.new);
