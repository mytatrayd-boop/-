import 'arabic.dart';
import 'prayer.dart';
import 'widget_layout.dart';
import 'widget_theme.dart';

export 'widget_layout.dart';

/// إعدادات المستخدم التي يُبنى منها الجدول.
class Settings {
  Settings({
    required this.latitude,
    required this.longitude,
    required this.cityName,
    this.timeZone = defaultTimeZone,
    this.prayerMethod = defaultPrayerMethod,
    required Set<String> deposits,
    List<TileLayout>? layout,
    this.opacity = 100,
    this.background,
    this.theme = WidgetTheme.fallback,
    this.lockNotification = false,
    this.fontScale = FontScale.fallback,
    this.digits = DigitStyle.fallback,
    this.prayerCountdown = false,
  })  : deposits = Set.unmodifiable(deposits),
        layout = normalizeLayout(layout ?? defaultLayout) {
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

  /// تخطيط الودجت (الميزة ٥): كل العناصر بترتيبها وإعداداتها.
  final List<TileLayout> layout;

  /// العناصر الظاهرة.
  Set<WidgetElement> get visible => {
    for (final t in layout)
      if (t.visible) t.id,
  };

  /// شفافية خلفية الودجت 0–100.
  final int opacity;

  /// اسم ملف لقطة الخلفية داخل حاوية App Group (آيفون)، أو null.
  final String? background;

  /// سمة لون الودجت والمعاينة.
  final WidgetTheme theme;

  /// إشعار ثابت في شاشة القفل (أندرويد)، مطفأ افتراضياً.
  final bool lockNotification;

  /// حجم الخط (متوسط افتراضياً).
  final FontScale fontScale;

  /// شكل الأرقام في نصوص الجدول (عربية افتراضياً).
  final DigitStyle digits;

  /// العدّاد التنازلي للصلاة القادمة تحت الساعة (آيفون) وفي مربع «الصلاة القادمة»: مطفأ افتراضياً
  /// (طلب المالك ٣٠/١٠/٢٠٢٦).
  final bool prayerCountdown;
}
