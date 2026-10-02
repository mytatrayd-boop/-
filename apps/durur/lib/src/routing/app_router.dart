import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../domain/month_day.dart';
import '../features/about/origin_screen.dart';
import '../features/city_picker/city_picker_screen.dart';
import '../features/home/home_screen.dart';
import '../features/item_detail/detail_data.dart';
import '../features/item_detail/item_detail_page.dart';
import '../features/onboarding/location_screen.dart';
import '../features/onboarding/notifications_intro_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/sources_screen.dart';
import 'app_routes.dart';

export 'app_routes.dart';

/// حالة التطبيق التي يحتاجها التوجيه التلقائي.
typedef RedirectState = ({
  String? savedCityId,
  bool onboardingDone,
  bool tablesReady,
  bool cityResolved,
});

/// التوجيه التلقائي:
/// - لا مدينة محفوظة (أول تشغيل أو بعد مسح بيانات التطبيق) ← شاشات البداية.
/// - مدينة محفوظة والإعداد الأولي لم ينتهِ (أُغلق التطبيق قبل شرح
///   التنبيهات) ← شرح التنبيهات (ARCHITECTURE §3، §12).
/// - مدينة محفوظة لكنها لم تعد في القائمة ← اختيار المدينة (DESIGN 8.4).
/// شاشات البداية نفسها لا يُعاد توجيهها (فيها تُختار المدينة).
String? appRedirect(String location, RedirectState s) {
  if (location.startsWith(AppRoutes.onboarding)) return null;
  if (s.savedCityId == null) return AppRoutes.onboarding;
  if (s.tablesReady && !s.cityResolved) return AppRoutes.onboardingCity;
  if (!s.onboardingDone) return AppRoutes.onboardingNotifications;
  return null;
}

GoRouter createAppRouter({
  required RedirectState Function() readState,
  Listenable? refreshListenable,
}) => GoRouter(
  refreshListenable: refreshListenable,
  redirect: (context, state) => appRedirect(state.matchedLocation, readState()),
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
      path: AppRoutes.sources,
      builder: (context, state) => const SourcesScreen(),
    ),
    GoRoute(
      path: AppRoutes.origin,
      builder: (context, state) => const OriginScreen(),
    ),
    GoRoute(
      path: '/item/:id',
      builder: (context, state) => ItemDetailPage(
        target: ItemTarget(state.pathParameters['id']!),
        from: AppRoutes.parseFrom(state.uri.queryParameters['from']),
      ),
    ),
    GoRoute(
      path: '/dar/:regionId/:start',
      builder: (context, state) {
        MonthDay? start;
        try {
          start = MonthDay.parse(state.pathParameters['start']!, 'route');
        } on FormatException {
          start = null;
        }
        // تاريخ غير صالح ← الصفحة لا تجد سجلها فتعود للرئيسية.
        return ItemDetailPage(
          target: start == null
              ? null
              : DarTarget(state.pathParameters['regionId']!, start),
          from: AppRoutes.parseFrom(state.uri.queryParameters['from']),
        );
      },
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
      path: AppRoutes.onboardingNotifications,
      builder: (context, state) => const NotificationsIntroScreen(),
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
