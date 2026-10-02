import '../domain/month_day.dart';
import '../features/city_picker/city_picker_screen.dart' show CityPickerNotice;
import '../features/item_detail/detail_data.dart';

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

  /// شاشات البداية (DESIGN 8.2): الترحيب ← شرح الموقع ← اختيار المدينة
  /// ← شرح التنبيهات.
  static const onboarding = '/onboarding';
  static const onboardingLocation = '/onboarding/location';

  /// شرح التنبيهات وطلب إذنها (DESIGN 8.2 د)، آخر شاشات البداية.
  static const onboardingNotifications = '/onboarding/notifications';

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
