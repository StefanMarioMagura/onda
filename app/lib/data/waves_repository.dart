import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme.dart';
import '../domain/affinity.dart';
import '../domain/wave.dart';
import '../main.dart' show supabaseConfigured;
import 'sample_data.dart';

/// The ondas the feed shows, and whether they are real or sample content.
class TodayWaves {
  const TodayWaves(this.waves, {this.day, this.isSample = false});
  final List<Wave> waves;

  /// Feed day they were published for (null for sample content).
  final DateTime? day;
  final bool isSample;
}

abstract class WavesRepository {
  Future<TodayWaves> today();
}

class SampleWavesRepository implements WavesRepository {
  @override
  Future<TodayWaves> today() async => const TodayWaves(sampleWaves, isSample: true);
}

/// Reads published ondas (RLS lets the app see nothing else). Shows the most
/// recent published day up to today; sample content until anything is published.
class SupabaseWavesRepository implements WavesRepository {
  SupabaseWavesRepository(this.client);
  final SupabaseClient client;

  @override
  Future<TodayWaves> today() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final latest = await client
        .from('ondas')
        .select('publicada_para')
        .lte('publicada_para', today)
        .order('publicada_para', ascending: false)
        .limit(1)
        .maybeSingle();
    if (latest == null) return const TodayWaves(sampleWaves, isSample: true);
    final day = latest['publicada_para'] as String;
    final rows = await client.from('ondas').select('id, capa, contenido').eq('publicada_para', day).order('id');
    return TodayWaves([for (final r in rows) waveFromRow(r)], day: DateTime.parse(day));
  }
}

const _layers = {'bolsillo': Capa.bolsillo, 'pais': Capa.pais, 'mundo': Capa.mundo};
const _axes = {'economia': PolAxis.economia, 'sociedad': PolAxis.sociedad, 'territorio': PolAxis.territorio};

/// One published row ({id, capa, contenido}) into a Wave. Pure, so it is unit-tested.
Wave waveFromRow(Map<String, dynamic> row) {
  final content = row['contenido'] as Map<String, dynamic>;
  final shores = content['shores'] as Map<String, dynamic>?;
  final stance = content['stance'] as Map<String, dynamic>?;
  return Wave(
    id: 'onda-${row['id']}',
    layer: _layers[row['capa']] ?? Capa.mundo,
    source: content['source'] as String? ?? '',
    cards: [
      for (final c in (content['cards'] as List).cast<Map<String, dynamic>>())
        WaveCard(
          headline: c['headline'] as String,
          body: c['body'] as String,
          figure: c['figure'] == null
              ? null
              : KeyFigure(c['figure']['value'] as String, c['figure']['caption'] as String),
          teaser: c['teaser'] as String?,
          actions: [for (final a in (c['actions'] as List? ?? const [])) a as String],
        ),
    ],
    shores: shores == null
        ? null
        : TwoShores(
            supporters: shores['supporters'] as String,
            critics: shores['critics'] as String,
            sharedFacts: [for (final f in shores['shared_facts'] as List) f as String],
          ),
    stance: stance == null || stance.isEmpty
        ? null
        : Stance({
            for (final MapEntry(:key, :value) in stance.entries) ?_axes[key]: (value as num).toDouble(),
          }),
  );
}

final wavesRepositoryProvider = Provider<WavesRepository>(
    (ref) => supabaseConfigured ? SupabaseWavesRepository(Supabase.instance.client) : SampleWavesRepository());

final todayWavesProvider = FutureProvider<TodayWaves>((ref) => ref.watch(wavesRepositoryProvider).today());
