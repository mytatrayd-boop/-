import 'package:durur/src/domain/month_day.dart';
import 'package:durur/src/features/city_picker/city_picker_screen.dart';
import 'package:durur/src/features/item_detail/detail_data.dart';
import 'package:durur/src/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RedirectState state({
    String? cityId,
    bool ready = true,
    bool resolved = false,
    bool done = true,
  }) => (
    savedCityId: cityId,
    onboardingDone: done,
    tablesReady: ready,
    cityResolved: resolved,
  );

  group('appRedirect', () {
    test('لا مدينة محفوظة ← شاشات البداية (حتى قبل تحميل الجداول)', () {
      expect(appRedirect('/', state(ready: false)), AppRoutes.onboarding);
      expect(appRedirect('/', state()), AppRoutes.onboarding);
      expect(appRedirect('/settings', state()), AppRoutes.onboarding);
    });

    test('مدينة محفوظة وموجودة ← لا توجيه', () {
      expect(appRedirect('/', state(cityId: 'riyadh', resolved: true)), isNull);
    });

    test('مدينة محفوظة لم تعد في القائمة ← اختيار المدينة (DESIGN 8.4)', () {
      expect(appRedirect('/', state(cityId: 'gone')), AppRoutes.onboardingCity);
    });

    test('قبل تحميل الجداول لا يُحكم على المدينة المحفوظة', () {
      expect(appRedirect('/', state(cityId: 'riyadh', ready: false)), isNull);
    });

    test('الميزة 8: مدينة محفوظة والإعداد الأولي لم ينتهِ ← شرح التنبيهات', () {
      for (final loc in ['/', '/settings', '/item/wasm']) {
        expect(
          appRedirect(loc, state(cityId: 'riyadh', resolved: true, done: false)),
          AppRoutes.onboardingNotifications,
          reason: loc,
        );
      }
      // قبل تحميل الجداول أيضاً، ولا مدينة ← البداية من أولها.
      expect(
        appRedirect('/', state(cityId: 'riyadh', ready: false, done: false)),
        AppRoutes.onboardingNotifications,
      );
      expect(appRedirect('/', state(done: false)), AppRoutes.onboarding);
      // مدينة لم تعد موجودة تُختار أولاً.
      expect(
        appRedirect('/', state(cityId: 'gone', done: false)),
        AppRoutes.onboardingCity,
      );
    });

    test('شاشات البداية لا يُعاد توجيهها', () {
      for (final loc in [
        AppRoutes.onboarding,
        AppRoutes.onboardingLocation,
        AppRoutes.onboardingCity,
        AppRoutes.onboardingNotifications,
      ]) {
        expect(appRedirect(loc, state()), isNull, reason: loc);
        expect(appRedirect(loc, state(cityId: 'gone')), isNull, reason: loc);
      }
    });
  });

  test('رابط القائمة مع سطر السبب', () {
    expect(AppRoutes.onboardingCityWith(null), '/onboarding/city');
    expect(
      AppRoutes.onboardingCityWith(CityPickerNotice.outOfRange),
      '/onboarding/city?notice=outOfRange',
    );
    for (final n in CityPickerNotice.values) {
      expect(CityPickerNotice.parse(n.name), n);
    }
    expect(CityPickerNotice.parse(null), isNull);
    expect(CityPickerNotice.parse('x'), isNull);
  });

  test('مسارات الميزة 7: العنصر والدَّرّ (D26) والتاريخ المرجعي', () {
    expect(AppRoutes.item('suhail'), '/item/suhail');
    expect(
      AppRoutes.item('suhail', from: DateTime(2026, 10, 2)),
      '/item/suhail?from=2026-10-02',
    );
    expect(
      AppRoutes.dar('uae_oman', const MonthDay(8, 15)),
      '/dar/uae_oman/08-15',
    );
    expect(
      AppRoutes.detail(const DarTarget('kuwait', MonthDay(1, 5))),
      '/dar/kuwait/01-05',
    );
    expect(AppRoutes.detail(const ItemTarget('wasm')), '/item/wasm');
    expect(AppRoutes.parseFrom('2026-10-02'), DateTime(2026, 10, 2));
    expect(AppRoutes.parseFrom('2026-02-30'), isNull);
    expect(AppRoutes.parseFrom('x'), isNull);
    expect(AppRoutes.parseFrom(null), isNull);
    expect(AppRoutes.origin, '/about/origin');
    expect(AppRoutes.sources, '/settings/sources');
  });
}
