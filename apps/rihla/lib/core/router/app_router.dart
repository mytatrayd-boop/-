import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/onboarding_permissions/permissions_controller.dart';
import '../../features/onboarding_permissions/permissions_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/not_found_screen.dart';
import '../../features/summary/summary_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const home = '/';
  static const settings = '/settings';
  static const permissions = '/permissions';
  static const summary = '/summary';
  static String summaryFor(String id, {String? reason}) =>
      '$summary/$id${reason == null ? '' : '?reason=$reason'}';
}

GoRouter buildRouter({String initialLocation = AppRoutes.home}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      path: '${AppRoutes.summary}/:id',
      builder: (_, st) => SummaryScreen(
        tripId: st.pathParameters['id']!,
        reason: st.uri.queryParameters['reason'],
      ),
    ),
    GoRoute(
      path: AppRoutes.permissions,
      builder: (_, _) => const PermissionsScreen(),
    ),
  ],
  errorBuilder: (_, _) => const NotFoundScreen(),
);

/// مسار الإقلاع: /permissions إن نقصت الكاميرا أو الموقع الدقيق، وإلا الرئيسية.
/// (الميكروفون اختياري فلا يمنع.) يُستدعى في main بعد فحص الأذونات.
String initialLocationFor(PermissionsState p) =>
    p.canStartRecording ? AppRoutes.home : AppRoutes.permissions;

final initialLocationProvider = Provider<String>((_) => AppRoutes.home);

final routerProvider = Provider<GoRouter>((ref) {
  final r = buildRouter(initialLocation: ref.read(initialLocationProvider));
  ref.onDispose(r.dispose);
  return r;
});
