import 'dart:math';

/// Political map: where the user's ratings place them, and which party is
/// closest. Method in docs/producto/concepto-v2.md. Everything here runs on
/// the device; the ratings it uses never leave it.

/// The three axes, on the CHES 0-10 scales.
enum PolAxis {
  economia('Economía', 'Izquierda', 'Derecha'),
  sociedad('Sociedad', 'Progresista', 'Conservador'),
  territorio('Territorio', 'Más autogobierno', 'Más centralismo');

  const PolAxis(this.label, this.low, this.high);
  final String label;

  /// Meaning of 0 and of 10.
  final String low;
  final String high;
}

/// A user's rating of a news item, story or debate.
enum Vote {
  mal(-1, 'Mal'),
  igual(0, 'Me da igual'),
  bien(1, 'Bien');

  const Vote(this.sign, this.label);
  final int sign;
  final String label;
}

/// Editorial marking of a political item: rating it "bien" pushes the user
/// towards the high end (+) or the low end (−) of each axis. Non-political
/// items have no stance and don't count.
class Stance {
  const Stance(this.weights);
  final Map<PolAxis, double> weights;
}

class Party {
  const Party({
    required this.id,
    required this.short,
    required this.name,
    required this.leader,
    required this.seats,
    required this.position,
  });

  final String id;
  final String short;
  final String name;
  final String? leader;
  final int seats;
  final Map<PolAxis, double> position;
}

class PartyMatch {
  const PartyMatch(this.party, this.similarity);
  final Party party;

  /// 0-1: 1 means the same point as the party.
  final double similarity;
}

class AffinityResult {
  const AffinityResult({required this.position, required this.evidence, required this.matches});

  /// User position per axis (0-10), or null while there aren't enough ratings.
  final Map<PolAxis, double?> position;

  /// How many political ratings count on each axis.
  final Map<PolAxis, int> evidence;

  /// Parties from most to least similar (empty until at least one axis is known).
  final List<PartyMatch> matches;

  bool get hasAnyAxis => position.values.any((v) => v != null);
  bool get isComplete => position.values.every((v) => v != null);
}

/// Ratings needed on an axis before showing a position on it.
const minVotesPerAxis = 3;

AffinityResult computeAffinity({
  required Map<String, Vote> votes,
  required Map<String, Stance> stances,
  required List<Party> parties,
}) {
  final position = <PolAxis, double?>{};
  final evidence = <PolAxis, int>{};
  for (final axis in PolAxis.values) {
    var sum = 0.0;
    var weight = 0.0;
    var count = 0;
    for (final MapEntry(key: id, value: vote) in votes.entries) {
      final w = stances[id]?.weights[axis] ?? 0;
      if (w == 0) continue;
      count++;
      sum += vote.sign * w;
      weight += w.abs();
    }
    evidence[axis] = count;
    // −1..1 (all ratings towards one end) mapped onto the 0..10 scale.
    position[axis] = count >= minVotesPerAxis ? 5 + 5 * (sum / weight) : null;
  }

  final known = [for (final a in PolAxis.values) if (position[a] != null) a];
  final maxDistance = sqrt(known.length * 100);
  final matches = known.isEmpty
      ? <PartyMatch>[]
      : ([
          for (final p in parties)
            PartyMatch(
              p,
              1 -
                  sqrt(known.fold<double>(0, (acc, a) => acc + pow(position[a]! - p.position[a]!, 2))) /
                      maxDistance,
            ),
        ]..sort((a, b) => b.similarity.compareTo(a.similarity)));

  return AffinityResult(position: position, evidence: evidence, matches: matches);
}

/// Political "family" from the economic and social axes, plus a territorial
/// nuance. Descriptive labels used in political science, not party names.
String politicalFamily(Map<PolAxis, double?> position) {
  final eco = position[PolAxis.economia];
  final soc = position[PolAxis.sociedad];
  if (eco == null || soc == null) return 'Aún sin definir';
  final String base;
  if (eco < 4 && soc < 4) {
    base = 'Izquierda progresista';
  } else if (eco > 6 && soc > 6) {
    base = 'Derecha conservadora';
  } else if (eco > 6 && soc < 4) {
    base = 'Liberal';
  } else if (eco < 4 && soc > 6) {
    base = 'Izquierda tradicional';
  } else if (eco < 4.5) {
    base = 'Centroizquierda';
  } else if (eco > 5.5) {
    base = 'Centroderecha';
  } else {
    base = 'Centro';
  }
  final terr = position[PolAxis.territorio];
  if (terr == null) return base;
  if (terr < 3) return '$base, a favor de más autogobierno';
  if (terr > 7) return '$base, centralista';
  return base;
}
