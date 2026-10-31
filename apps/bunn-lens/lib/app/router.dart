import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cafes/presentation/cafes_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/history/presentation/scan_detail_screen.dart';
import '../features/scan/presentation/scan_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'shell.dart';

abstract class AppRoutes {
  static const scan = '/scan';
  static const history = '/history';
  static const favorites = '/favorites';
  static const settings = '/settings';
  static const cafes = '/cafes';
}

GoRouter buildRouter({String initialLocation = AppRoutes.scan}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: AppRoutes.cafes, builder: (_, _) => const CafesScreen()),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: AppRoutes.scan, builder: (_, _) => const ScanScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (_, _) => const HistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        ScanDetailScreen(id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.favorites,
                builder: (_, _) => const FavoritesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => ScanDetailScreen(
                      id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                      fallbackRoute: AppRoutes.favorites,
                    ),
                  ),
                ],
              ),
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
