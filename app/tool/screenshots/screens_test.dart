// Renders the main screens to PNG with the real fonts, phone-sized (390x844 @3x).
// Not part of the normal test run. Regenerate with:
//   flutter test tool/screenshots --update-goldens
// Output: tool/screenshots/out/*.png
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers.dart';
import '../../test/perfil_test.dart' show leftVotes;

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

Future<void> _settle(WidgetTester tester) async {
  // Some screens animate forever (milestone arrow, clips): advance time instead of settling.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
}

void main() {
  setUpAll(() async {
    await _loadFont('Archivo', 'assets/fonts/Archivo.ttf');
    await _loadFont('MaterialIcons',
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));

  testWidgets('feed', (tester) async {
    await pumpApp(tester);
    await shot('01_onda_que_paso');
    for (var i = 0; i < 3; i++) {
      await tapForward(tester);
    }
    await shot('02_onda_que_haces_con_dial');
    await tester.drag(find.byIcon(Icons.swap_horiz_rounded), const Offset(120, 0));   // mid-slide
    await tester.pump();
    await shot('03_dial_deslizando');
  });

  testWidgets('descubre debate', (tester) async {
    await pumpApp(tester);
    for (var i = 0; i < 19; i++) {
      await tapForward(tester);
    }
    await tapForward(tester, settle: false);
    await tester.pump(const Duration(seconds: 2));
    // Scroll Descubre until the first debate.
    for (var i = 0; i < 30 && find.text('¿ESTÁS A FAVOR?').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(PageView).first, const Offset(0, -700));
      await _settle(tester);
    }
    await shot('04_debate');
  });

  testWidgets('tu españa', (tester) async {
    await pumpApp(tester);
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
    await pumpApp(tester);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await shot('07_perfil_sin_activar');
    await tester.tap(find.text('ACTIVAR MI MAPA POLÍTICO'));
    await tester.pumpAndSettle();
    await shot('08_consentimiento');
  });

  testWidgets('perfil con mapa', (tester) async {
    await pumpApp(tester, stored: {'political_map_consent_v1': true, 'votes_v1': jsonEncode(leftVotes)});
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await shot('09_mapa_politico');
    await tester.drag(find.byType(ListView).last, const Offset(0, -650));
    await tester.pumpAndSettle();
    await shot('10_mapa_ejes');
  });
}
