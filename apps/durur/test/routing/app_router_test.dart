import 'package:durur/src/features/city_picker/city_picker_screen.dart';
import 'package:durur/src/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RedirectState state({
    String? cityId,
    bool ready = true,
    bool resolved = false,
  }) => (savedCityId: cityId, tablesReady: ready, cityResolved: resolved);

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

    test('شاشات البداية لا يُعاد توجيهها', () {
      for (final loc in [
        AppRoutes.onboarding,
        AppRoutes.onboardingLocation,
        AppRoutes.onboardingCity,
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
}
