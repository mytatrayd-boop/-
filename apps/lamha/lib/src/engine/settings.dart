import 'prayer.dart';
import 'widget_theme.dart';

/// عناصر الودجت التي يمكن إخفاؤها (SPEC §4ب). الساعة واليوم ثابتة.
enum WidgetElement {
  hijri,
  gregorian,
  weather,
  prayer,
  qibla,
  deposit,
  season,
  tradSeason,
}

/// إعدادات المستخدم التي يُبنى منها الجدول.
class Settings {
  Settings({
    required this.latitude,
    required this.longitude,
    required this.cityName,
    this.timeZone = defaultTimeZone,
    this.prayerMethod = defaultPrayerMethod,
    required Set<String> deposits,
    Set<WidgetElement>? visible,
    this.opacity = 100,
    this.background,
    this.theme = WidgetTheme.fallback,
    this.lockNotification = false,
  })  : deposits = Set.unmodifiable(deposits),
        visible = Set.unmodifiable(visible ?? WidgetElement.values.toSet()) {
    if (deposits.isEmpty) {
      throw ArgumentError.value(
          deposits, 'deposits', 'لا يمكن إلغاء الإيداعات كلها');
    }
    if (opacity < 0 || opacity > 100) {
      throw RangeError.range(opacity, 0, 100, 'opacity');
    }
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw ArgumentError('إحداثيات غير صالحة ($latitude، $longitude)');
    }
    if (!prayerMethods.containsKey(prayerMethod)) {
      throw ArgumentError.value(prayerMethod, 'prayerMethod');
    }
  }

  final double latitude;
  final double longitude;
  final String cityName;

  /// اسم المنطقة الزمنية IANA (مثل `Asia/Riyadh`).
  final String timeZone;

  /// معرّف طريقة الحساب من [prayerMethods].
  final String prayerMethod;

  /// معرّفات الإيداعات المختارة (واحد على الأقل).
  final Set<String> deposits;

  final Set<WidgetElement> visible;

  /// شفافية خلفية الودجت 0–100.
  final int opacity;

  /// اسم ملف لقطة الخلفية داخل حاوية App Group (آيفون)، أو null.
  final String? background;

  /// سمة لون الودجت والمعاينة.
  final WidgetTheme theme;

  /// إشعار ثابت في شاشة القفل (أندرويد)، مطفأ افتراضياً.
  final bool lockNotification;
}
