import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/parties_ches2024.dart';
import 'package:onda/data/sample_data.dart';
import 'package:onda/domain/affinity.dart';

const eco = Stance({PolAxis.economia: 1});      // "bien" = towards the right
const ecoL = Stance({PolAxis.economia: -1});    // "bien" = towards the left
const soc = Stance({PolAxis.sociedad: 1});
const socL = Stance({PolAxis.sociedad: -1});
const ter = Stance({PolAxis.territorio: 1});
const terL = Stance({PolAxis.territorio: -1});

AffinityResult run(Map<String, Vote> votes, Map<String, Stance> stances) =>
    computeAffinity(votes: votes, stances: stances, parties: partiesChes2024);

void main() {
  group('computeAffinity', () {
    test('no position until 3 ratings on an axis', () {
      final r = run({'a': Vote.bien, 'b': Vote.bien}, {'a': eco, 'b': eco});
      expect(r.position[PolAxis.economia], isNull);
      expect(r.evidence[PolAxis.economia], 2);
      expect(r.matches, isEmpty);
      expect(r.hasAnyAxis, isFalse);
    });

    test('all ratings towards one end give 0 or 10', () {
      final right = run({'a': Vote.bien, 'b': Vote.bien, 'c': Vote.mal},
          {'a': eco, 'b': eco, 'c': ecoL});
      expect(right.position[PolAxis.economia], 10);
      final left = run({'a': Vote.mal, 'b': Vote.mal, 'c': Vote.bien},
          {'a': eco, 'b': eco, 'c': ecoL});
      expect(left.position[PolAxis.economia], 0);
    });

    test('"me da igual" pulls towards the centre', () {
      final r = run({'a': Vote.bien, 'b': Vote.igual, 'c': Vote.igual}, {'a': eco, 'b': eco, 'c': eco});
      expect(r.position[PolAxis.economia], closeTo(5 + 5 / 3, 1e-9));
    });

    test('ratings on non-political items are ignored', () {
      final r = run({'luz': Vote.bien, 'a': Vote.bien, 'b': Vote.bien, 'c': Vote.bien},
          {'a': eco, 'b': eco, 'c': eco});
      expect(r.evidence[PolAxis.economia], 3);
    });

    Map<String, Vote> allTowards({required bool right}) => {
          for (final id in ['e1', 'e2', 'e3', 's1', 's2', 's3', 't1', 't2', 't3'])
            id: right ? Vote.bien : Vote.mal,
        };
    const stances = {'e1': eco, 'e2': eco, 'e3': eco, 's1': soc, 's2': soc, 's3': soc, 't1': ter, 't2': ter, 't3': ter};

    test('right, conservative and centralist ratings match Vox first', () {
      final r = run(allTowards(right: true), stances);
      expect(r.isComplete, isTrue);
      expect(r.matches.first.party.short, 'Vox');
      expect(politicalFamily(r.position), 'Derecha conservadora, centralista');
    });

    test('left, progressive and pro-self-government ratings match a left nationalist party', () {
      final r = run(allTowards(right: false), stances);
      expect(['EH Bildu', 'ERC', 'BNG'], contains(r.matches.first.party.short));
      expect(politicalFamily(r.position), 'Izquierda progresista, a favor de más autogobierno');
    });

    test('similarity is between 0 and 1 and sorted', () {
      final r = run(allTowards(right: true), stances);
      for (final m in r.matches) {
        expect(m.similarity, inInclusiveRange(0, 1));
      }
      expect(r.matches.map((m) => m.similarity).toList(),
          [...r.matches.map((m) => m.similarity)]..sort((a, b) => b.compareTo(a)));
    });

    test('with one axis only, parties are compared on that axis', () {
      final r = run({'e1': Vote.mal, 'e2': Vote.mal, 'e3': Vote.mal}, stances);
      expect(r.position[PolAxis.sociedad], isNull);
      expect(r.matches, isNotEmpty);
      expect(r.isComplete, isFalse);
    });
  });

  test('party data comes from CHES with all three axes', () {
    expect(partiesChes2024.length, 14);
    for (final p in partiesChes2024) {
      expect(p.position.keys.toSet(), PolAxis.values.toSet(), reason: p.short);
      for (final v in p.position.values) {
        expect(v, inInclusiveRange(0, 10), reason: p.short);
      }
    }
  });

  test('sample content is balanced: on each axis, as many items push each way', () {
    final stances = ProviderContainer().read(stancesProvider);
    for (final axis in PolAxis.values) {
      final weights = [for (final s in stances.values) s.weights[axis] ?? 0].where((w) => w != 0).toList();
      final up = weights.where((w) => w > 0).fold<double>(0, (a, w) => a + w);
      final down = weights.where((w) => w < 0).fold<double>(0, (a, w) => a - w);
      expect(up, down, reason: '${axis.label}: $up towards ${axis.high}, $down towards ${axis.low}');
      expect(weights.length, greaterThanOrEqualTo(2 * minVotesPerAxis), reason: axis.label);
    }
  });
}
