import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show supabaseConfigured;

/// Regulated electricity price (PVPC) for one day, hour by hour, in €/kWh.
/// PVPC energy term from Red Eléctrica: includes tolls and charges, not taxes.
class LuzDay {
  const LuzDay(this.hours, {this.isSample = false});

  /// (start of hour, €/kWh), sorted.
  final List<(DateTime, double)> hours;
  final bool isSample;

  double get average => hours.fold<double>(0, (a, h) => a + h.$2) / hours.length;
  (DateTime, double) get cheapest => hours.reduce((a, b) => b.$2 < a.$2 ? b : a);
  (DateTime, double) get priciest => hours.reduce((a, b) => b.$2 > a.$2 ? b : a);

  /// Price of the hour that contains [now], or null if [now] is outside the day.
  double? priceAt(DateTime now) {
    for (final (hour, price) in hours) {
      if (!now.isBefore(hour) && now.isBefore(hour.add(const Duration(hours: 1)))) return price;
    }
    return null;
  }

  /// From luz_horaria rows ({hour, pvpc_eur_mwh}), converting €/MWh to €/kWh.
  factory LuzDay.fromRows(List<Map<String, dynamic>> rows) {
    final hours = [
      for (final r in rows)
        (DateTime.parse(r['hour'] as String).toLocal(), (r['pvpc_eur_mwh'] as num).toDouble() / 1000),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return LuzDay(hours);
  }
}

abstract class LuzRepository {
  /// Today's hours, or null if they aren't loaded yet.
  Future<LuzDay?> today();
}

class SampleLuzRepository implements LuzRepository {
  @override
  Future<LuzDay?> today() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    // Typical winter weekday shape: cheap at night and midday, peak in the evening.
    const shape = [0.21, 0.20, 0.19, 0.19, 0.19, 0.20, 0.23, 0.27, 0.29, 0.26, 0.22, 0.19,
                   0.17, 0.16, 0.16, 0.17, 0.20, 0.26, 0.33, 0.39, 0.40, 0.35, 0.28, 0.24];
    return LuzDay([for (var h = 0; h < 24; h++) (start.add(Duration(hours: h)), shape[h])], isSample: true);
  }
}

class SupabaseLuzRepository implements LuzRepository {
  SupabaseLuzRepository(this.client);
  final SupabaseClient client;

  @override
  Future<LuzDay?> today() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final rows = await client
        .from('luz_horaria')
        .select('hour, pvpc_eur_mwh')
        .gte('hour', start.toUtc().toIso8601String())
        .lt('hour', start.add(const Duration(days: 1)).toUtc().toIso8601String())
        .order('hour');
    return rows.isEmpty ? null : LuzDay.fromRows(rows);
  }
}

final luzRepositoryProvider = Provider<LuzRepository>(
    (ref) => supabaseConfigured ? SupabaseLuzRepository(Supabase.instance.client) : SampleLuzRepository());

final luzTodayProvider = FutureProvider<LuzDay?>((ref) => ref.watch(luzRepositoryProvider).today());
