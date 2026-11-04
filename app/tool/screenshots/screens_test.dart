// Renders the main screens to PNG with the real fonts, phone-sized (390x844 @3x).
// Not part of the normal test run. Regenerate with:
//   flutter test tool/screenshots --update-goldens
// Output: tool/screenshots/out/*.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/main.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  }
  await loader.load();
}

String get _flutterRoot => Platform.environment['FLUTTER_ROOT']!;

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: OndaApp()));
  await tester.pumpAndSettle();
}

Future<void> _tapForward(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tapAt(const Offset(300, 450));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    await _loadFont('Newsreader', ['assets/fonts/Newsreader.ttf']);
    await _loadFont('IBMPlexSans', ['assets/fonts/IBMPlexSans.ttf']);
    await _loadFont('MaterialIcons', ['$_flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  Future<void> shot(WidgetTester tester, String name) =>
      expectLater(find.byType(OndaApp), matchesGoldenFile('out/$name.png'));

  testWidgets('feed', (tester) async {
    await _pump(tester);
    await shot(tester, '1_onda_que_paso');
    await _tapForward(tester, 2);
    await shot(tester, '2_onda_como_te_llega');
    await _tapForward(tester, 1);
    await shot(tester, '3_onda_que_haces');
    await _tapForward(tester, 2);
    await shot(tester, '4_pais_por_que_importa');
    await tester.tap(find.text('Las dos orillas'));
    await tester.pumpAndSettle();
    await shot(tester, '5_dos_orillas');
  });

  testWidgets('end of feed', (tester) async {
    await _pump(tester);
    await _tapForward(tester, 20);
    await shot(tester, '6_fin');
  });

  testWidgets('bolsillo', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Tu bolsillo'));
    await tester.pumpAndSettle();
    await shot(tester, '7_bolsillo');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await shot(tester, '8_bolsillo_gasolineras');
  });
}
