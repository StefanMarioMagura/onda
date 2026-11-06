import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/explain.dart';
import '../domain/fuel.dart';
import '../domain/semaforo.dart';
import '../main.dart' show supabaseConfigured;
import 'sample_data.dart';

/// Approximate location used to search nearby stations. Rounded to 2 decimals
/// (~1 km) before it leaves the device (GDPR: location only approximate).
class ApproxLocation {
  ApproxLocation(this.name, double lat, double lon)
      : lat = _round(lat),
        lon = _round(lon);

  final String name;
  final double lat;
  final double lon;

  static double _round(double v) => (v * 100).round() / 100;
}

/// Until the user can pick a zone, stations are searched around central Madrid.
final defaultLocation = ApproxLocation('Madrid', 40.4168, -3.7038);

abstract class PocketRepository {
  Future<PocketSnapshot> load(Fuel fuel);
}

class SamplePocketRepository implements PocketRepository {
  @override
  Future<PocketSnapshot> load(Fuel fuel) async => samplePocket(fuel);
}

/// Reads the semáforo, the national price history and nearby stations from Supabase.
class SupabasePocketRepository implements PocketRepository {
  SupabasePocketRepository(this.client, this.location);
  final SupabaseClient client;
  final ApproxLocation location;

  @override
  Future<PocketSnapshot> load(Fuel fuel) async {
    final (forecast, history, stations) = await (
      client
          .from('semaforo_diario')
          .select()
          .eq('fuel', fuel.code)
          .eq('province_id', '00')
          .order('day', ascending: false)
          .limit(1)
          .maybeSingle(),
      client
          .from('precios_diarios')
          .select('day, avg_price')
          .eq('fuel', fuel.code)
          .eq('province_id', '00')
          .order('day', ascending: false)
          .limit(30),
      client.rpc('nearby_prices', params: {
        'p_fuel': fuel.code,
        'p_lat': location.lat,
        'p_lon': location.lon,
        'p_radius_km': 10,
        'p_limit': 5,
      }),
    ).wait;
    if (forecast == null) throw StateError('No hay previsión del semáforo para ${fuel.label}');
    return pocketFromRows(
      fuel: fuel,
      location: location,
      forecast: forecast,
      history: List<Map<String, dynamic>>.from(history),
      stations: List<Map<String, dynamic>>.from(stations as List),
    );
  }
}

/// The Ministry sometimes leaves trailing commas or spaces ("CALLE JOSE PAULETE,").
String _tidy(Object? v) => (v ?? '').toString().trim().replaceAll(RegExp(r'[,\s]+$'), '');

double _num(Object? v) => v is num ? v.toDouble() : double.parse(v.toString());

/// Builds the snapshot from database rows. Pure, so it is unit-tested.
PocketSnapshot pocketFromRows({
  required Fuel fuel,
  required ApproxLocation location,
  required Map<String, dynamic> forecast,
  required List<Map<String, dynamic>> history,
  required List<Map<String, dynamic>> stations,
}) {
  final days = [...history]..sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
  return PocketSnapshot(
    fuel: fuel,
    areaName: location.name,
    priceArea: 'España',
    averagePrice: _num(forecast['price']),
    last30Days: [for (final d in days) _num(d['avg_price'])],
    expectedChange7d: _num(forecast['expected_change']),
    reason: explainForecast(
      price7: _num(forecast['price_7']),
      signal: Signal.fromExpectedChange(_num(forecast['expected_change'])),
    ),
    forecastDay: DateTime.parse(forecast['day'] as String),
    areaAveragePrice: stations.isEmpty ? null : _num(stations.first['area_avg_price']),
    areaStationCount: stations.isEmpty ? null : (stations.first['area_station_count'] as num).toInt(),
    stations: [
      for (final s in stations)
        Station(
          brand: titleCase(s['brand'] as String),
          address: titleCase('${_tidy(s['address'])}, ${_tidy(s['locality'])}'),
          distanceKm: _num(s['distance_km']),
          price: _num(s['price']),
        ),
    ],
  );
}

final pocketRepositoryProvider = Provider<PocketRepository>((ref) => supabaseConfigured
    ? SupabasePocketRepository(Supabase.instance.client, defaultLocation)
    : SamplePocketRepository());

/// Retries a failed load twice on its own (flaky mobile networks), then shows
/// the error with a manual "Reintentar".
Duration? pocketRetry(int retryCount, Object error) => retryCount < 2 ? const Duration(seconds: 1) : null;

final pocketProvider = FutureProvider.family<PocketSnapshot, Fuel>(
  (ref, fuel) => ref.watch(pocketRepositoryProvider).load(fuel),
  retry: pocketRetry,
);
