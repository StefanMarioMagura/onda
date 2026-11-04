import 'package:flutter_test/flutter_test.dart';
import 'package:onda/domain/format.dart';
import 'package:onda/domain/semaforo.dart';

void main() {
  group('Signal.fromExpectedChange (same thresholds as the Python model)', () {
    test('rises more than 1 cent -> verde', () => expect(Signal.fromExpectedChange(0.0101), Signal.verde));
    test('exactly +1 cent is still ámbar', () => expect(Signal.fromExpectedChange(0.01), Signal.ambar));
    test('no change -> ámbar', () => expect(Signal.fromExpectedChange(0), Signal.ambar));
    test('exactly −1 cent is still ámbar', () => expect(Signal.fromExpectedChange(-0.01), Signal.ambar));
    test('falls more than 1 cent -> rojo', () => expect(Signal.fromExpectedChange(-0.0101), Signal.rojo));
  });

  group('savingEur', () {
    test('cheaper station saves the difference times the litres', () {
      expect(savingEur(referencePrice: 1.512, stationPrice: 1.454), closeTo(2.90, 1e-9));
    });
    test('custom tank size', () {
      expect(savingEur(referencePrice: 1.5, stationPrice: 1.4, litres: 40), closeTo(4.0, 1e-9));
    });
    test('a pricier station never shows a negative saving', () {
      expect(savingEur(referencePrice: 1.512, stationPrice: 1.539), 0);
    });
  });

  group('Spanish formatting', () {
    test('euros', () => expect(euros(4.2), '4,20 €'));
    test('fuel price has 3 decimals', () => expect(fuelPrice(1.5), '1,500'));
    test('cents with sign', () {
      expect(cents(0.024), '+2,4 cént.');
      expect(cents(-0.003), '−0,3 cént.');
      expect(cents(0.0001), '0,0 cént.');
      expect(cents(0.024, signed: false), '2,4 cént.');
    });
    test('km', () => expect(km(1.85), '1,9 km'));
  });
}
