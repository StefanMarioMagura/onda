import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/affinity.dart';

/// Device storage. Overridden in main() (and in tests) with a loaded instance.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider not set'));

/// The user's ratings, by item id. Stored only on this device: they are the
/// input of the political map, i.e. special-category data (GDPR art. 9).
class VotesNotifier extends Notifier<Map<String, Vote>> {
  static const _key = 'votes_v1';

  @override
  Map<String, Vote> build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final byName = Vote.values.asNameMap();
    return {
      for (final MapEntry(:key, :value) in decoded.entries) key: ?byName[value],
    };
  }

  /// Records [vote] for [itemId] and returns the previous vote, if any.
  Vote? cast(String itemId, Vote vote) {
    final previous = state[itemId];
    state = {...state, itemId: vote};
    _save();
    return previous;
  }

  void clearAll() {
    state = const {};
    ref.read(prefsProvider).remove(_key);
  }

  void _save() => ref.read(prefsProvider).setString(_key, jsonEncode({
        for (final MapEntry(:key, :value) in state.entries) key: value.name,
      }));
}

final votesProvider = NotifierProvider<VotesNotifier, Map<String, Vote>>(VotesNotifier.new);

/// Explicit, separate consent to compute the political map (off by default).
class PoliticalMapConsent extends Notifier<bool> {
  static const _key = 'political_map_consent_v1';

  @override
  bool build() => ref.watch(prefsProvider).getBool(_key) ?? false;

  void set(bool value) {
    state = value;
    ref.read(prefsProvider).setBool(_key, value);
  }
}

final politicalMapConsentProvider = NotifierProvider<PoliticalMapConsent, bool>(PoliticalMapConsent.new);
