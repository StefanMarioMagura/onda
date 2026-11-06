import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'state/votes_state.dart';

// Passed at build time, never hardcoded.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Without these values (tests, quick runs) the app falls back to sample data.
/// Local runs: flutter run --dart-define-from-file=env.json (see env.example.json).
const supabaseConfigured = supabaseUrl != '' && supabasePublishableKey != '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const OndaApp(),
  ));
}

class OndaApp extends StatelessWidget {
  const OndaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ONDA',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'ES'),
      theme: ondaTheme(),
      scrollBehavior: const OndaScrollBehavior(),
      routerConfig: router,
    );
  }
}
