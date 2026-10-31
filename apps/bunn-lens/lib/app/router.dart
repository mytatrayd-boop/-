import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/favorites/presentation/favorites_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/scan/presentation/scan_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'shell.dart';

abstract class AppRoutes {
  static const scan = '/scan';
  static const history = '/history';
  static const favorites = '/favorites';
  static const settings = '/settings';
}

GoRouter buildRouter({String initialLocation = AppRoutes.scan}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.scan, builder: (_, _) => const ScanScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.history, builder: (_, _) => const HistoryScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.favorites, builder: (_, _) => const FavoritesScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsScreen()),
            ]),
          ],
        ),
      ],
    );

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
