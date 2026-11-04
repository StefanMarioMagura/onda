import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';

// Passed at build time, never hardcoded:
// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  }
  runApp(const ProviderScope(child: OndaApp()));
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
