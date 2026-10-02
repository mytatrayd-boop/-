import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../domain/month_day.dart';
import '../features/about/origin_screen.dart';
import '../features/city_picker/city_picker_screen.dart';
import '../features/home/home_screen.dart';
import '../features/item_detail/detail_data.dart';
import '../features/item_detail/item_detail_page.dart';
import '../features/onboarding/location_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/sources_screen.dart';

/// المسارات. مسارا العنصر والدَّرّ يُستخدمان أيضاً كحمولة (payload)
/// للتنبيهات (الميزة 8).
abstract final class AppRoutes {
  static const home = '/';
  static const city = '/city';
  static const settings = '/settings';

  /// صفحة المصادر (D27).
  static const sources = '/settings/sources';

  /// صفحة «أصل التقويم» (D24).
  static const origin = '/about/origin';

  /// صفحة نجم أو موسم أو موسم جو. [from] التاريخ المرجعي للفترة المعروضة
  /// (الافتراضي: التاريخ المعروض في الرئيسية).
  static String item(String itemId, {DateTime? from}) => Uri(
    path: '/item/$itemId',
    queryParameters: from == null ? null : {'from': _ymd(from)},
  ).toString();

  /// صفحة دَرّ من سجله (D26): [regionId] جدول الدرور الفعلي و[start] بدايته.
  static String dar(String regionId, MonthDay start, {DateTime? from}) => Uri(
    path: '/dar/$regionId/$start',
    queryParameters: from == null ? null : {'from': _ymd(from)},
  ).toString();

  /// مسار هدف صفحة.
  static String detail(DetailTarget target, {DateTime? from}) =>
      switch (target) {
        ItemTarget(:final itemId) => item(itemId, from: from),
        DarTarget(:final regionId, :final start) => dar(
          regionId,
          start,
          from: from,
        ),
      };

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// يقرأ `from=YYYY-MM-DD`؛ null إن غاب أو لم يصح.
  static DateTime? parseFrom(String? value) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value ?? '');
    if (m == null) return null;
    final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    return _ymd(d) == value ? d : null;
  }

  /// شاشات البداية (DESIGN 8.2): الترحيب ← شرح الموقع ← اختيار المدينة.
  static const onboarding = '/onboarding';
  static const onboardingLocation = '/onboarding/location';

  /// اختيار المدينة بلا رجوع (أول تشغيل، أو مدينة محفوظة غير موجودة).
  static const onboardingCity = '/onboarding/city';

  /// [notice] رسالة أعلى القائمة بعد فشل تحديد الموقع.
  static String onboardingCityWith(CityPickerNotice? notice) => notice == null
      ? onboardingCity
      : Uri(
          path: onboardingCity,
          queryParameters: {'notice': notice.name},
        ).toString();
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
      path: AppRoutes.onboardingCity,
      builder: (context, state) => CityPickerScreen(
        firstRun: true,
        notice: CityPickerNotice.parse(state.uri.queryParameters['notice']),
        onSaved: () => context.go(AppRoutes.home),
      ),
    ),
  ],
);
