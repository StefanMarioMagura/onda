import 'semaforo.dart';

enum Fuel {
  gasoleoA('Gasóleo A', 'gasoleo_a'),
  gasolina95('Gasolina 95', 'gasolina_95_e5');

  const Fuel(this.label, this.code);
  final String label;

  /// Code used in the database (precios.fuel, semaforo_diario.fuel).
  final String code;
}

class Station {
  const Station({required this.brand, required this.address, required this.distanceKm, required this.price});
  final String brand;
  final String address;
  final double distanceKm;
  final double price;
}

/// Everything "Tu bolsillo" shows for one fuel.
class PocketSnapshot {
  const PocketSnapshot({
    required this.fuel,
    required this.areaName,
    required this.priceArea,
    required this.averagePrice,
    required this.last30Days,
    required this.expectedChange7d,
    required this.reason,
    required this.stations,
    this.forecastDay,
    this.isSample = false,
    this.areaAveragePrice,
    this.areaStationCount,
  });

  final Fuel fuel;

  /// Where the stations are searched ("Madrid").
  final String areaName;

  /// What the average price and the semáforo cover ("España").
  final String priceArea;
  final double averagePrice;
  final List<double> last30Days;
  final double expectedChange7d;
  final String reason;
  final List<Station> stations;

  /// Day the forecast starts from (last day with known prices).
  final DateTime? forecastDay;
  final bool isSample;

  /// Average price of all stations within the search radius, and how many there are.
  final double? areaAveragePrice;
  final int? areaStationCount;

  /// What a station's saving is measured against: the area if known, else the average shown.
  double get stationReferencePrice => areaAveragePrice ?? averagePrice;

  Signal get signal => Signal.fromExpectedChange(expectedChange7d);
  double get change7dSoFar =>
      last30Days.length < 8 ? 0 : last30Days.last - last30Days[last30Days.length - 8];
}
