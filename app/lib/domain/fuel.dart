import 'semaforo.dart';

enum Fuel {
  gasoleoA('Gasóleo A'),
  gasolina95('Gasolina 95');

  const Fuel(this.label);
  final String label;
}

class Station {
  const Station({required this.brand, required this.address, required this.distanceKm, required this.price});
  final String brand;
  final String address;
  final double distanceKm;
  final double price;
}

/// Everything "Tu bolsillo" shows for one fuel in the user's area.
class PocketSnapshot {
  const PocketSnapshot({
    required this.fuel,
    required this.areaName,
    required this.averagePrice,
    required this.last30Days,
    required this.expectedChange7d,
    required this.reason,
    required this.stations,
  });

  final Fuel fuel;
  final String areaName;
  final double averagePrice;
  final List<double> last30Days;
  final double expectedChange7d;
  final String reason;
  final List<Station> stations;

  Signal get signal => Signal.fromExpectedChange(expectedChange7d);
  double get change7dSoFar => last30Days.last - last30Days[last30Days.length - 8];
}
