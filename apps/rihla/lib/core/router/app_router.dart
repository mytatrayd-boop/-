import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/not_found_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const home = '/';
  static const settings = '/settings';
}

GoRouter buildRouter({String initialLocation = AppRoutes.home}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
      errorBuilder: (_, __) => const NotFoundScreen(),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final r = buildRouter();
  ref.onDispose(r.dispose);
  return r;
});

