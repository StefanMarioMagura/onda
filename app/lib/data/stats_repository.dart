import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show supabaseConfigured;

/// One value of an official series (INE). [period] is the first day of the
/// month (CPI) or of the year (salaries).
class StatPoint {
  const StatPoint(this.period, this.value);
  final DateTime period;
  final double value;
}

/// Official statistics for "Tu España".
class SpainStats {
  const SpainStats({
    required this.foodCpi,
    required this.generalCpi,
    required this.salaryMean,
    required this.salaryMedian,
    this.isSample = false,
  });

  /// Annual change (%) of food and non-alcoholic drink prices, by month.
  final List<StatPoint> foodCpi;

  /// Annual change (%) of overall prices, by month.
  final List<StatPoint> generalCpi;

  /// Mean and median gross annual salary (€), by year.
  final List<StatPoint> salaryMean;
  final List<StatPoint> salaryMedian;
  final bool isSample;

  /// Change of the latest mean salary against the year before, in %.
  double? get salaryChangePct {
    if (salaryMean.length < 2) return null;
    final last = salaryMean[salaryMean.length - 1].value;
    final prev = salaryMean[salaryMean.length - 2].value;
    return (last / prev - 1) * 100;
  }

  /// What [amount] € of food shopping a year ago costs now, from the latest food CPI.
  double? basketToday(double amount) => foodCpi.isEmpty ? null : amount * (1 + foodCpi.last.value / 100);

  /// Builds the stats from indicadores rows ({serie, periodo, valor}).
  factory SpainStats.fromRows(List<Map<String, dynamic>> rows) {
    List<StatPoint> series(String name) => [
          for (final r in rows)
            if (r['serie'] == name)
              StatPoint(DateTime.parse(r['periodo'] as String), (r['valor'] as num).toDouble()),
        ]..sort((a, b) => a.period.compareTo(b.period));
    return SpainStats(
      foodCpi: series('ipc_alimentos_anual'),
      generalCpi: series('ipc_general_anual'),
      salaryMean: series('salario_medio'),
      salaryMedian: series('salario_mediana'),
    );
  }
}

const statsSeries = ['ipc_alimentos_anual', 'ipc_general_anual', 'salario_medio', 'salario_mediana'];

abstract class StatsRepository {
  Future<SpainStats> load();
}

class SupabaseStatsRepository implements StatsRepository {
  SupabaseStatsRepository(this.client);
  final SupabaseClient client;

  @override
  Future<SpainStats> load() async {
    final rows = await client
        .from('indicadores')
        .select('serie, periodo, valor')
        .inFilter('serie', statsSeries)
        .order('periodo');
    return SpainStats.fromRows(rows);
  }
}

/// Used without Supabase (tests). Values copied from INE for realism, but flagged as sample.
class SampleStatsRepository implements StatsRepository {
  @override
  Future<SpainStats> load() async {
    final months = [for (var m = 0; m < 13; m++) DateTime(2025, 9 + m)];
    const food = [2.4, 2.4, 2.8, 3.0, 3.0, 3.2, 2.7, 2.6, 2.2, 1.9, 1.6, 2.3, 2.7];
    return SpainStats(
      foodCpi: [for (var i = 0; i < 13; i++) StatPoint(months[i], food[i])],
      generalCpi: [StatPoint(DateTime(2026, 10), 4.9)],
      salaryMean: [StatPoint(DateTime(2023), 28049.94), StatPoint(DateTime(2024), 29540.26)],
      salaryMedian: [StatPoint(DateTime(2023), 23349.0), StatPoint(DateTime(2024), 24497.17)],
      isSample: true,
    );
  }
}

final statsRepositoryProvider = Provider<StatsRepository>(
    (ref) => supabaseConfigured ? SupabaseStatsRepository(Supabase.instance.client) : SampleStatsRepository());

final spainStatsProvider = FutureProvider<SpainStats>((ref) => ref.watch(statsRepositoryProvider).load());
