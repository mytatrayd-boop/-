import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/city_picker/city_picker_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/location_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/settings/settings_screen.dart';

/// المسارات. مسار صفحة العنصر (/item/:id) يُضاف في الميزة 7،
/// ويُستخدم أيضاً كحمولة (payload) للتنبيهات.
abstract final class AppRoutes {
  static const home = '/';
  static const city = '/city';
  static const settings = '/settings';

  /// شاشات البداية (DESIGN 8.2): الترحيب ← شرح الموقع ← اختيار المدينة.
  static const onboarding = '/onboarding';
  static const onboardingLocation = '/onboarding/location';

  /// اختيار المدينة بلا رجوع (أول تشغيل، أو مدينة محفوظة غير موجودة).
  static const onboardingCity = '/onboarding/city';

  /// [notice] رسالة أعلى القائمة بعد فشل تحديد الموقع.
  static String onboardingCityWith(CityPickerNotice? notice) => notice == null
      ? onboardingCity
      : Uri(path: onboardingCity, queryParameters: {'notice': notice.name})
          .toString();
}

/// حالة التطبيق التي يحتاجها التوجيه التلقائي.
typedef RedirectState = ({
  String? savedCityId,
  bool tablesReady,
  bool cityResolved,
});

/// التوجيه التلقائي:
/// - لا مدينة محفوظة (أول تشغيل أو بعد مسح بيانات التطبيق) ← شاشات البداية.
/// - مدينة محفوظة لكنها لم تعد في القائمة ← اختيار المدينة (DESIGN 8.4).
/// شاشات البداية نفسها لا يُعاد توجيهها (فيها تُختار المدينة).
String? appRedirect(String location, RedirectState s) {
  if (location.startsWith(AppRoutes.onboarding)) return null;
  if (s.savedCityId == null) return AppRoutes.onboarding;
  if (s.tablesReady && !s.cityResolved) return AppRoutes.onboardingCity;
  return null;
}

GoRouter createAppRouter({
  required RedirectState Function() readState,
  Listenable? refreshListenable,
}) =>
    GoRouter(
      refreshListenable: refreshListenable,
      redirect: (context, state) =>
          appRedirect(state.matchedLocation, readState()),
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
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboardingLocation,
          builder: (context, state) => const LocationScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboardingCity,
          builder: (context, state) => CityPickerScreen(
            firstRun: true,
            notice: CityPickerNotice.parse(state.uri.queryParameters['notice']),
            onSaved: () => context.go(AppRoutes.home),
          ),
        ),
      ],
    );
