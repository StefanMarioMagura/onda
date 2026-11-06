import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/pocket_repository.dart';
import 'package:onda/data/sample_data.dart';
import 'package:onda/domain/explain.dart';
import 'package:onda/domain/fuel.dart';
import 'package:onda/domain/semaforo.dart';
import 'package:onda/main.dart';
import 'package:onda/state/speech.dart';

import 'helpers.dart';

// Shapes copied from real Supabase responses (semaforo_diario, precios_diarios, cheapest_stations).
const forecastRow = {
  'day': '2026-11-04', 'fuel': 'gasolina_95_e5', 'price': 1.705, 'expected_change': -0.0163,
  'signal': 'rojo', 'price_7': -0.0328, 'margin_gap': -0.1533, 'model': 'v2',
};
final historyRows = [
  {'day': '2026-11-04', 'avg_price': 1.705},
  {'day': '2026-11-02', 'avg_price': 1.721},
  {'day': '2026-11-03', 'avg_price': 1.712},
];
final stationRows = [
  {'brand': 'SIMON GRUP', 'address': 'CARRETERA VILLAVERDE A VALLECAS KM. 283', 'locality': 'MADRID',
   'distance_km': 7.41, 'price': 1.749, 'area_avg_price': 1.919, 'area_station_count': 207},
  {'brand': 'ALCAMPO', 'address': 'CALLE JOSE PAULETE, ', 'locality': 'MADRID',
   'distance_km': 4.8, 'price': 1.759, 'area_avg_price': 1.919, 'area_station_count': 207},
];

void main() {
  group('pocketFromRows', () {
    final pocket = pocketFromRows(
      fuel: Fuel.gasolina95,
      location: defaultLocation,
      forecast: forecastRow,
      history: historyRows,
      stations: stationRows,
    );

    test('uses the forecast and its day', () {
      expect(pocket.expectedChange7d, -0.0163);
      expect(pocket.signal, Signal.rojo);
      expect(pocket.averagePrice, 1.705);
      expect(pocket.forecastDay, DateTime(2026, 11, 4));
      expect(pocket.isSample, isFalse);
      expect(pocket.priceArea, 'España');
    });

    test('sorts the price history by day', () {
      expect(pocket.last30Days, [1.721, 1.712, 1.705]);
    });

    test('explains the forecast from the weekly trend', () {
      expect(pocket.reason, startsWith('El precio ha bajado 3,3 cént. esta semana'));
    });

    test('measures savings against the area, not the national average', () {
      expect(pocket.areaAveragePrice, 1.919);
      expect(pocket.areaStationCount, 207);
      expect(pocket.stationReferencePrice, 1.919);
    });

    test('tidies station names from the Ministry capitals', () {
      final s = pocket.stations.first;
      expect(s.brand, 'Simon Grup');
      expect(s.address, 'Carretera Villaverde a Vallecas Km. 283, Madrid');
      expect(s.distanceKm, 7.41);
      expect(pocket.stations[1].address, 'Calle Jose Paulete, Madrid');   // no double comma
    });

    test('accepts numbers sent as strings (Postgres numeric)', () {
      final p = pocketFromRows(
        fuel: Fuel.gasoleoA,
        location: defaultLocation,
        forecast: {...forecastRow, 'price': '1.890', 'expected_change': '-0.0026', 'price_7': '-0.0090'},
        history: const [],
        stations: const [],
      );
      expect(p.averagePrice, 1.89);
      expect(p.signal, Signal.ambar);
      expect(p.change7dSoFar, 0);
      expect(p.stationReferencePrice, 1.89);   // no stations: falls back to the average shown
    });
  });

  test('retries twice automatically, then gives up', () {
    expect(pocketRetry(0, Exception()), const Duration(seconds: 1));
    expect(pocketRetry(1, Exception()), const Duration(seconds: 1));
    expect(pocketRetry(2, Exception()), isNull);
  });

  test('location is rounded to about 1 km before leaving the device', () {
    final loc = ApproxLocation('Casa', 40.416775, -3.703790);
    expect(loc.lat, 40.42);
    expect(loc.lon, -3.70);
  });

  group('forecast text never contradicts the verdict', () {
    test('verde/rojo following the weekly trend', () {
      expect(explainForecast(price7: 0.012, signal: Signal.verde), startsWith('El precio ha subido 1,2 cént.'));
      expect(explainForecast(price7: -0.033, signal: Signal.rojo), startsWith('El precio ha bajado 3,3 cént.'));
    });
    test('ámbar after a move says it will not continue', () {
      final text = explainForecast(price7: -0.009, signal: Signal.ambar);
      expect(text, contains('ha bajado 0,9 cént.'));
      expect(text, contains('no esperamos'));
      expect(text, isNot(contains('suelen continuar')));
    });
    test('ámbar when flat', () {
      expect(explainForecast(price7: 0.002, signal: Signal.ambar), startsWith('El precio apenas se ha movido'));
    });
    test('verde against the trend is explained by the margin', () {
      expect(explainForecast(price7: -0.01, signal: Signal.verde), contains('márgenes'));
    });
    test('main sentence per signal', () {
      expect(forecastSentence(Signal.rojo, -0.0163), 'Se espera que baje 1,6 cént. por litro en 7 días.');
      expect(forecastSentence(Signal.verde, 0.024), 'Se espera que suba 2,4 cént. por litro en 7 días.');
      expect(forecastSentence(Signal.ambar, -0.0026), startsWith('Se espera que se mueva menos de 1 cént.'));
    });
  });

  test('titleCase keeps short connectors lower-case', () {
    expect(titleCase('CALLE DE LA PAZ, 3'), 'Calle de la Paz, 3');
    expect(titleCase('BALLENOIL'), 'Ballenoil');
  });

  test('without Supabase config the app uses the sample repository', () {
    expect(supabaseConfigured, isFalse);
    expect(ProviderContainer().read(pocketRepositoryProvider), isA<SamplePocketRepository>());
  });

  testWidgets('Tu bolsillo shows an error with retry when loading fails', (tester) async {
    var calls = 0;
    final repo = _FailingTimes(3, () => calls++);   // initial load + 2 automatic retries
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        speechProvider.overrideWithValue(FakeSpeech()),
        pocketRepositoryProvider.overrideWithValue(repo),
      ],
      child: const OndaApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tu bolsillo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));   // let the automatic retries run out
    await tester.pumpAndSettle();
    expect(find.text('NO HEMOS PODIDO CARGAR LOS PRECIOS'), findsOneWidget);
    expect(calls, 3);

    await tester.tap(find.text('REINTENTAR'));
    await tester.pumpAndSettle();
    expect(find.text('LLENA HOY'), findsOneWidget);
    expect(calls, 4);
  });
}

class _FailingTimes implements PocketRepository {
  _FailingTimes(this.failures, this.onCall);
  final int failures;
  final VoidCallback onCall;
  var _calls = 0;

  @override
  Future<PocketSnapshot> load(Fuel fuel) async {
    onCall();
    if (_calls++ < failures) throw Exception('network down');
    return samplePocket(fuel);
  }
}
