/// Semáforo "¿lleno hoy o espero?". Same rule as the Python model
/// (workers/onda_workers/semaforo/features.py): verde if the price is expected
/// to rise more than 1 cent/l in 7 days, rojo if it is expected to fall more
/// than 1 cent/l, ámbar otherwise.
enum Signal {
  verde('Llena hoy'),
  ambar('Da igual'),
  rojo('Espera');

  const Signal(this.verdict);
  final String verdict;

  static const thresholdEur = 0.01;

  static Signal fromExpectedChange(double eurPerLitre) {
    if (eurPerLitre > thresholdEur) return Signal.verde;
    if (eurPerLitre < -thresholdEur) return Signal.rojo;
    return Signal.ambar;
  }
}

/// Money saved filling [litres] at [stationPrice] instead of [referencePrice] (€/l).
/// Never negative: a pricier station saves nothing.
double savingEur({required double referencePrice, required double stationPrice, double litres = 50}) {
  final saving = (referencePrice - stationPrice) * litres;
  return saving > 0 ? saving : 0;
}
