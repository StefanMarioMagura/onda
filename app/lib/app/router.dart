import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/bolsillo/bolsillo_screen.dart';
import '../features/espana/espana_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/perfil/perfil_screen.dart';

final router = GoRouter(
  initialLocation: '/hoy',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/hoy', builder: (context, state) => const FeedScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/espana',
            builder: (context, state) => const EspanaScreen(),
            routes: [
              GoRoute(path: 'carburantes', builder: (context, state) => const BolsilloScreen()),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/perfil', builder: (context, state) => const PerfilScreen()),
        ]),
      ],
    ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.waves_rounded), label: 'Hoy'),
          NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Tu España'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}
