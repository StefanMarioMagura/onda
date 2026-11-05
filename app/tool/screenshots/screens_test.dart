// Renders the main screens to PNG with the real fonts, phone-sized (390x844 @3x).
// Not part of the normal test run. Regenerate with:
//   flutter test tool/screenshots --update-goldens
// Output: tool/screenshots/out/*.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers.dart';

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
    await tapForward(tester);
    await tapForward(tester);
    await shot('02_onda_como_te_llega');
    await tapForward(tester);
    await shot('03_onda_que_haces');
    await tester.tapAt(const Offset(250, 250)); // completes the onda
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // mid-celebration
    await shot('04_celebracion');
    await tester.pumpAndSettle();
    await tapForward(tester);
    await tester.tap(find.text('LAS DOS ORILLAS'));
    await tester.pumpAndSettle();
    await shot('05_dos_orillas');
  });

  testWidgets('milestone and descubre', (tester) async {
    await pumpApp(tester);
    for (var i = 0; i < 19; i++) {
      await tapForward(tester);
    }
    await tapForward(tester, settle: false);
    await tester.pump(const Duration(seconds: 2));
    await shot('06_hito');
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(PageView).first, const Offset(0, -700));
      await _settle(tester);
      await shot('${(7 + i).toString().padLeft(2, '0')}_descubre_${i + 1}');
    }
  });

  testWidgets('bolsillo', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Tu bolsillo'));
    await tester.pumpAndSettle();
    await shot('13_bolsillo');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await shot('14_bolsillo_gasolineras');
  });
}
