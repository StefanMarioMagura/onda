// Renders the main screens to PNG with the real fonts, phone-sized (390x844 @3x).
// Not part of the normal test run. Regenerate with:
//   flutter test tool/screenshots --update-goldens
// Output: tool/screenshots/out/*.png
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/data/news_repository.dart';
import 'package:onda/domain/news.dart';

import '../../test/helpers.dart';
import '../../test/perfil_test.dart' show leftVotes;

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

/// A realistic day, written by hand for the screenshots.
class _Demo implements NewsRepository {
  @override
  Future<TodayNews> load() async => const TodayNews(
        topics: [
          NewsTopic(
            id: 'tema-demo',
            headline: 'El Gobierno aprueba la subida del salario mínimo para el próximo año',
            summary: 'La medida afecta a unos dos millones de trabajadores y entrará en vigor el 1 de enero, tras la negociación con los sindicatos.',
            url: 'https://example.com/a',
            outletName: 'Medio A',
            outlets: 5,
            headlines: [
              OutletHeadline(outlet: 'Medio A', side: NewsSide.izquierda, title: 'Más sueldo para dos millones de trabajadores', url: 'https://example.com/a'),
              OutletHeadline(outlet: 'Medio B', side: NewsSide.izquierda, title: 'Los sindicatos celebran la subida del salario mínimo', url: 'https://example.com/b'),
              OutletHeadline(outlet: 'Medio C', side: NewsSide.centro, title: 'Aprobada la subida del salario mínimo', url: 'https://example.com/c'),
              OutletHeadline(outlet: 'Medio D', side: NewsSide.derecha, title: 'La patronal avisa: la subida frenará la contratación', url: 'https://example.com/d'),
              OutletHeadline(outlet: 'Medio E', side: NewsSide.derecha, title: 'El Gobierno sube el salario mínimo sin el apoyo de las empresas', url: 'https://example.com/e'),
            ],
          ),
        ],
        latest: [],
      );
}

void main() {
  setUpAll(() async {
    await _loadFont('Archivo', 'assets/fonts/Archivo.ttf');
    await _loadFont('MaterialIcons',
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));

  testWidgets('feed', (tester) async {
    await pumpApp(tester, news: _Demo());
    await shot('01_tema_del_dia');
    await tester.tap(find.text('LAS DOS ORILLAS'));
    await tester.pumpAndSettle();
    await shot('02_dos_orillas');
  });

  testWidgets('milestone', (tester) async {
    await pumpApp(tester, news: _Demo());
    await swipeToNext(tester);
    await shot('03_hito');
  });

  testWidgets('descubre debate', (tester) async {
    await pumpApp(tester, news: _Demo());
    await swipeToNext(tester);
    for (var i = 0; i < 40 && find.text('¿ESTÁS A FAVOR?').evaluate().isEmpty; i++) {
      await swipeToNext(tester);
    }
    await shot('04_debate');
  });

  testWidgets('tu españa', (tester) async {
    await pumpApp(tester, news: _Demo());
    await tester.tap(find.text('Tu España'));
    await tester.pumpAndSettle();
    await shot('05_tu_espana');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await shot('05b_tu_espana_compra_salario');
    await tester.drag(find.byType(ListView).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CARBURANTES'));
    await tester.pumpAndSettle();
    await shot('06_carburantes');
  });

  testWidgets('perfil', (tester) async {
    await pumpApp(tester, news: _Demo());
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await shot('07_perfil_sin_activar');
    await tester.tap(find.text('ACTIVAR MI MAPA POLÍTICO'));
    await tester.pumpAndSettle();
    await shot('08_consentimiento');
  });

  testWidgets('perfil con mapa', (tester) async {
    await pumpApp(tester, news: _Demo(), stored: {'political_map_consent_v1': true, 'votes_v1': jsonEncode(leftVotes)});
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await shot('09_mapa_politico');
    await tester.drag(find.byType(ListView).last, const Offset(0, -650));
    await tester.pumpAndSettle();
    await shot('10_mapa_ejes');
  });
}
