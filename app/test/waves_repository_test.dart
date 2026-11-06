import 'package:flutter_test/flutter_test.dart';
import 'package:onda/app/theme.dart';
import 'package:onda/data/waves_repository.dart';
import 'package:onda/domain/affinity.dart';

// Shape of a published row as Supabase returns it (contenido built by onda_workers.news.generate).
Map<String, dynamic> row({Map<String, dynamic>? shores, Map<String, dynamic>? stance}) => {
      'id': 42,
      'capa': 'pais',
      'contenido': {
        'cards': [
          for (var i = 1; i <= 3; i++)
            {'headline': 'Tarjeta $i', 'body': 'Texto $i', 'figure': null, 'teaser': '¿Y ahora?', 'actions': []},
          {
            'headline': 'Qué hacer',
            'body': 'Texto 4',
            'figure': {'value': '+50 €', 'caption': 'al mes'},
            'teaser': null,
            'actions': ['Revisa tu nómina.', 'Consulta el BOE.'],
          },
        ],
        'shores': shores,
        'stance': stance,
        'source': 'ABC · RTVE · elDiario.es',
        'links': [
          {'outlet': 'ABC', 'url': 'https://abc.es/b'},
        ],
      },
    };

void main() {
  test('maps a published row to a Wave with a stable id for votes', () {
    final wave = waveFromRow(row());
    expect(wave.id, 'onda-42');
    expect(wave.layer, Capa.pais);
    expect(wave.source, 'ABC · RTVE · elDiario.es');
    expect(wave.cards, hasLength(4));
    expect(wave.cards.first.teaser, '¿Y ahora?');
    expect(wave.cards.last.figure!.value, '+50 €');
    expect(wave.cards.last.actions, ['Revisa tu nómina.', 'Consulta el BOE.']);
    expect(wave.shores, isNull);
    expect(wave.stance, isNull);
  });

  test('two shores and political stance come through', () {
    final wave = waveFromRow(row(
      shores: {'supporters': 'A favor', 'critics': 'En contra', 'shared_facts': ['Sube a 1.250 €']},
      stance: {'economia': -1, 'desconocido': 1},
    ));
    expect(wave.shores!.sharedFacts, ['Sube a 1.250 €']);
    expect(wave.stance!.weights, {PolAxis.economia: -1.0});        // unknown axes ignored
  });

  test('without Supabase the feed uses sample ondas, flagged as such', () async {
    final today = await SampleWavesRepository().today();
    expect(today.isSample, isTrue);
    expect(today.waves, isNotEmpty);
  });
}
