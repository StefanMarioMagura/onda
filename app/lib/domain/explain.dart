import 'format.dart';
import 'semaforo.dart';

/// Main sentence under the verdict, e.g. "Se espera que baje 1,6 cént. por litro en 7 días."
String forecastSentence(Signal signal, double expectedChange) {
  final amount = cents(expectedChange.abs(), signed: false);
  return switch (signal) {
    Signal.verde => 'Se espera que suba $amount por litro en 7 días.',
    Signal.rojo => 'Se espera que baje $amount por litro en 7 días.',
    Signal.ambar => 'Se espera que se mueva menos de 1 cént. por litro en 7 días.',
  };
}

/// Plain-Spanish reason for a forecast, from the pump trend that drives the
/// v2 model (docs/decisiones/0006). It never contradicts the verdict.
String explainForecast({required double price7, required Signal signal}) {
  final moved = cents(price7.abs(), signed: false);
  final direction = price7 > 0 ? 'subido' : 'bajado';
  final flat = price7.abs() <= 0.005;
  const why = 'porque las gasolineras trasladan los cambios poco a poco';
  if (signal == Signal.ambar) {
    return flat
        ? 'El precio apenas se ha movido esta semana, así que no esperamos cambios grandes.'
        : 'El precio ha $direction $moved esta semana, pero no esperamos que siga moviéndose '
            'más de 1 céntimo.';
  }
  final continues = (signal == Signal.verde) == (price7 > 0);
  if (!flat && continues) {
    return 'El precio ha $direction $moved esta semana, y estos movimientos en el surtidor '
        'suelen continuar unos días $why.';
  }
  return signal == Signal.verde
      ? 'Aunque el precio no ha subido esta semana, los márgenes de las gasolineras están por '
          'debajo de lo normal y suelen recuperarse.'
      : 'Aunque el precio no ha bajado esta semana, los márgenes de las gasolineras están por '
          'encima de lo normal y suelen volver a su nivel.';
}

/// "CARRETERA VILLAVERDE A VALLECAS KM. 283" -> "Carretera Villaverde a Vallecas Km. 283".
/// The Ministry sends brands and addresses in capitals.
String titleCase(String text) {
  const lower = {'a', 'de', 'del', 'la', 'las', 'el', 'los', 'y', 'en'};
  final words = text.trim().toLowerCase().split(RegExp(r'\s+'));
  return [
    for (final (i, w) in words.indexed)
      if (w.isEmpty)
        w
      else if (i > 0 && lower.contains(w))
        w
      else
        w[0].toUpperCase() + w.substring(1),
  ].join(' ');
}
