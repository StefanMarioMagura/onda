/// Points, levels and streaks. Points are never bought nor exchanged for money
/// or prizes: that keeps predictions outside Spanish gambling law
/// (docs/diseno/principios.md).
abstract final class PointsRules {
  static const waveRead = 10;
  static const dailyMilestone = 50;
  static const quizCorrect = 20;
  static const pointsPerLevel = 100;
}

class Rewards {
  const Rewards({required this.points, required this.streakDays, this.claimed = const {}});

  final int points;
  final int streakDays;

  /// Keys of rewards already given (e.g. "wave:brent-sube"), so nothing pays twice.
  final Set<String> claimed;

  int get level => 1 + points ~/ PointsRules.pointsPerLevel;
  int get toNextLevel => PointsRules.pointsPerLevel - points % PointsRules.pointsPerLevel;
  double get levelProgress => (points % PointsRules.pointsPerLevel) / PointsRules.pointsPerLevel;

  bool hasClaimed(String key) => claimed.contains(key);

  /// Adds [amount] once per [key]; claiming the same key again changes nothing.
  Rewards claim(String key, int amount) {
    if (hasClaimed(key)) return this;
    return Rewards(points: points + amount, streakDays: streakDays, claimed: {...claimed, key});
  }

  /// Takes [amount] points (a prediction stake). Never below zero.
  Rewards spend(int amount) {
    if (amount > points) throw StateError('Not enough points: $points < $amount');
    return Rewards(points: points - amount, streakDays: streakDays, claimed: claimed);
  }
}

/// Streak after opening the app [today], given the last day it was opened.
/// Same day: unchanged. The day after: +1. Any longer gap: back to 1.
int streakAfterVisit({required DateTime? lastVisit, required int streak, required DateTime today}) {
  if (lastVisit == null) return 1;
  final last = DateTime(lastVisit.year, lastVisit.month, lastVisit.day);
  final now = DateTime(today.year, today.month, today.day);
  final gap = now.difference(last).inDays;
  if (gap <= 0) return streak;
  if (gap == 1) return streak + 1;
  return 1;
}

/// A yes/no prediction with points at stake, resolved with real data later.
/// Winning returns double the stake; losing returns nothing.
class Prediction {
  const Prediction({required this.stake, required this.saidYes});
  final int stake;
  final bool saidYes;

  int payout({required bool happened}) => saidYes == happened ? stake * 2 : 0;
}
