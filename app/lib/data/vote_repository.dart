import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/affinity.dart';
import '../main.dart' show supabaseConfigured;

/// Anonymous totals for one item.
class VoteTotals {
  const VoteTotals({required this.bien, required this.mal, required this.igual});
  final int bien;
  final int mal;
  final int igual;

  int get total => bien + mal + igual;

  double share(Vote vote) => total == 0
      ? 0
      : switch (vote) {
          Vote.bien => bien,
          Vote.mal => mal,
          Vote.igual => igual,
        } /
          total;
}

/// Below this many votes, percentages would be noise: the app shows none.
const minVotesToShowTotals = 10;

abstract class VoteRepository {
  /// Sends one anonymous vote (and takes back [previous] if the user changed it).
  Future<void> cast(String itemId, Vote vote, Vote? previous);
  Future<VoteTotals?> totals(String itemId);
}

/// Without a backend (tests, offline builds) votes stay local and there are no totals.
class LocalOnlyVoteRepository implements VoteRepository {
  @override
  Future<void> cast(String itemId, Vote vote, Vote? previous) async {}

  @override
  Future<VoteTotals?> totals(String itemId) async => null;
}

class SupabaseVoteRepository implements VoteRepository {
  SupabaseVoteRepository(this.client);
  final SupabaseClient client;

  @override
  Future<void> cast(String itemId, Vote vote, Vote? previous) =>
      client.rpc('cast_vote', params: {'p_item': itemId, 'p_vote': vote.name, 'p_previous': previous?.name});

  @override
  Future<VoteTotals?> totals(String itemId) async {
    final row = await client.from('votos_noticias').select('bien, mal, igual').eq('item_id', itemId).maybeSingle();
    if (row == null) return const VoteTotals(bien: 0, mal: 0, igual: 0);
    return VoteTotals(bien: row['bien'] as int, mal: row['mal'] as int, igual: row['igual'] as int);
  }
}

final voteRepositoryProvider = Provider<VoteRepository>(
    (ref) => supabaseConfigured ? SupabaseVoteRepository(Supabase.instance.client) : LocalOnlyVoteRepository());

final voteTotalsProvider =
    FutureProvider.family<VoteTotals?, String>((ref, itemId) => ref.watch(voteRepositoryProvider).totals(itemId));
