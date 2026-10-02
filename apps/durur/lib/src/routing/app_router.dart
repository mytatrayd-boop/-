import 'package:go_router/go_router.dart';

import '../features/city_picker/city_picker_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';

/// المسارات. مسار صفحة العنصر (/item/:id) يُضاف في الميزة 7،
/// ويُستخدم أيضاً كحمولة (payload) للتنبيهات.
abstract final class AppRoutes {
  static const home = '/';
  static const city = '/city';
  static const settings = '/settings';
}

GoRouter createAppRouter() => GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.city,
          builder: (context, state) => const CityPickerScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
