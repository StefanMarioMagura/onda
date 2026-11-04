import '../app/theme.dart';

/// The four steps every onda goes through, always in this order.
enum WaveStep {
  whatHappened('Qué pasó'),
  whyItMatters('Por qué importa'),
  howItReachesYou('Cómo te llega'),
  whatYouCanDo('Qué haces');

  const WaveStep(this.label);
  final String label;
}

/// A figure shown big on a card, e.g. "+6 cént." with "por litro en dos semanas".
class KeyFigure {
  const KeyFigure(this.value, this.caption);
  final String value;
  final String caption;
}

class WaveCard {
  const WaveCard({
    required this.headline,
    required this.body,
    this.figure,
    this.teaser,
    this.actions = const [],
  });

  final String headline;
  final String body;
  final KeyFigure? figure;

  /// Question answered by the next card (honest curiosity, not clickbait).
  final String? teaser;

  /// Concrete things the user can do (last card).
  final List<String> actions;
}

/// "Las dos orillas": how each side tells it, plus the facts both accept.
class TwoShores {
  const TwoShores({required this.supporters, required this.critics, required this.sharedFacts});
  final String supporters;
  final String critics;
  final List<String> sharedFacts;
}

class Wave {
  const Wave({
    required this.id,
    required this.layer,
    required this.cards,
    required this.source,
    this.shores,
  });

  final String id;
  final Capa layer;

  /// Always 4, one per [WaveStep] (checked in test/sample_data_test.dart).
  final List<WaveCard> cards;
  final String source;
  final TwoShores? shores;
}
