import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onda/main.dart';
import 'package:onda/state/speech.dart';
import 'package:onda/state/votes_state.dart';

import 'helpers.dart';

Future<void> openPerfil(WidgetTester tester, Map<String, Object> stored) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech()),
      prefsProvider.overrideWithValue(await testPrefs(stored)),
    ],
    child: const OndaApp(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
}

/// Answers "bien" to debates that push towards the low end of each axis
/// (left, progressive, more self-government) and "mal" on the others.
const leftVotes = {
  'debate-jornada-375': 'bien', 'debate-tope-alquiler': 'bien', 'debate-grandes-fortunas': 'bien',
  'debate-bajar-irpf': 'mal', 'debate-sucesiones': 'mal',
  'debate-eutanasia': 'bien', 'debate-regularizacion': 'bien', 'debate-inmigracion': 'mal',
  'debate-financiacion-singular': 'bien', 'debate-referendum': 'bien', 'debate-recentralizar': 'mal',
};

void main() {
  testWidgets('the political map needs explicit consent: Activar only after ticking the box', (tester) async {
    await openPerfil(tester, {});
    expect(find.text('¿A QUÉ PARTIDO TE PARECES?'), findsOneWidget);

    await tester.tap(find.text('ACTIVAR MI MAPA POLÍTICO'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ACTIVAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACTIVAR'));                       // disabled: nothing happens
    await tester.pumpAndSettle();
    expect(find.text('ANTES DE ACTIVARLO'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ACTIVAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACTIVAR'));
    await tester.pumpAndSettle();
    expect(find.text('VALORA PARA DESCUBRIRLO'), findsOneWidget);
  });

  testWidgets('with consent and enough ratings it shows the closest party and family', (tester) async {
    await openPerfil(tester, {
      'political_map_consent_v1': true,
      'votes_v1': jsonEncode(leftVotes),
    });
    expect(find.text('TE PARECES MÁS A'), findsOneWidget);
    expect(find.textContaining('Tu familia política: Izquierda progresista'), findsOneWidget);
  });

  testWidgets('deleting ratings resets the map', (tester) async {
    await openPerfil(tester, {
      'political_map_consent_v1': true,
      'votes_v1': jsonEncode(leftVotes),
    });
    await tester.ensureVisible(find.text('Borrar mis valoraciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar mis valoraciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(find.text('VALORA PARA DESCUBRIRLO'), findsOneWidget);
  });
}
