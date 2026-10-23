import 'dart:convert';

import '../engine/arabic.dart';
import '../engine/prayer.dart';
import '../engine/settings.dart';
import '../engine/widget_theme.dart';
import 'cities.dart';

/// إعدادات التطبيق المحفوظة في shared_preferences (مفتاح [prefsKey]).
class LamhaSettings {
  const LamhaSettings({
    required this.cityId,
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.timeZone,
    this.prayerMethod = defaultPrayerMethod,
    required this.deposits,
    this.layout = defaultLayout,
    this.opacity = 100,
    this.backgroundFile,
    this.theme = WidgetTheme.fallback,
    this.lockNotification = false,
    this.fontScale = FontScale.fallback,
    this.digits = DigitStyle.fallback,
  });

  factory LamhaSettings.defaults(City city, Set<String> depositIds) =>
      LamhaSettings(
        cityId: city.id,
        cityName: city.name,
        latitude: city.latitude,
        longitude: city.longitude,
        timeZone: city.timeZone,
        deposits: depositIds,
      );

  factory LamhaSettings.fromJson(Map<String, dynamic> j) => LamhaSettings(
        cityId: j['cityId'] as String,
        cityName: j['cityName'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        timeZone: j['timeZone'] as String,
        prayerMethod: j['prayerMethod'] as String,
        deposits: (j['deposits'] as List).cast<String>().toSet(),
        // الميزة ٥: التخطيط، وإعدادات أقدم بلاه تُرحَّل من مفاتيح visible.
        layout: j['layout'] is List
            ? migrateLayout([
                for (final t in (j['layout'] as List).cast<Map<String, dynamic>>())
                  if (WidgetElement.values.any((e) => e.name == t['id']))
                    TileLayout.fromJson(t),
              ])
            : layoutFromVisible(
                (j['visible'] as List? ?? const []).cast<String>()),
        opacity: j['opacity'] as int,
        backgroundFile: j['backgroundFile'] as String?,
        // مفتاحان جديدان (الميزة ٣ج)؛ الإعدادات القديمة بلاهما.
        // من حفظ قبل السمات رأى الذهبي، والجديد الأسود (الميزة ٦).
        theme: j.containsKey('theme')
            ? WidgetTheme.byName(j['theme'] as String?)
            : WidgetTheme.gold,
        lockNotification: j['lockNotification'] as bool? ?? false,
        // الميزة ٣د؛ الإعدادات القديمة بلاه = متوسط.
        fontScale: FontScale.byName(j['fontScale'] as String?),
        // الميزة ٦؛ الإعدادات القديمة بلاه = عربية.
        digits: DigitStyle.byName(j['digits'] as String?),
      );

  static const prefsKey = 'settings';

  final String cityId;
  final String cityName;
  final double latitude;
  final double longitude;
  final String timeZone;
  final String prayerMethod;
  final Set<String> deposits;
  /// تخطيط الودجت (الميزة ٥).
  final List<TileLayout> layout;
  final int opacity;

  /// اسم ملف لقطة الخلفية داخل حاوية App Group (آيفون)، لا مسار كامل.
  final String? backgroundFile;

  final WidgetTheme theme;

  /// إشعار ثابت في شاشة القفل (أندرويد).
  final bool lockNotification;

  /// حجم خط الودجت.
  final FontScale fontScale;

  /// شكل الأرقام في الودجت والمعاينة وشاشة القبلة والإشعار.
  final DigitStyle digits;

  /// [withBackground] = false في أندرويد، فيكون `background` في الجدول null.
  Settings toEngine({bool withBackground = true}) => Settings(
        latitude: latitude,
        longitude: longitude,
        cityName: cityName,
        timeZone: timeZone,
        prayerMethod: prayerMethod,
        deposits: deposits,
        layout: layout,
        opacity: opacity,
        background: withBackground ? backgroundFile : null,
        theme: theme,
        lockNotification: lockNotification,
        fontScale: fontScale,
        digits: digits,
      );

  LamhaSettings copyWith({
    String? cityId,
    String? cityName,
    double? latitude,
    double? longitude,
    String? timeZone,
    String? prayerMethod,
    Set<String>? deposits,
    List<TileLayout>? layout,
    int? opacity,
    String? backgroundFile,
    WidgetTheme? theme,
    bool? lockNotification,
    FontScale? fontScale,
    DigitStyle? digits,
  }) =>
      LamhaSettings(
        cityId: cityId ?? this.cityId,
        cityName: cityName ?? this.cityName,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        timeZone: timeZone ?? this.timeZone,
        prayerMethod: prayerMethod ?? this.prayerMethod,
        deposits: deposits ?? this.deposits,
        layout: layout ?? this.layout,
        opacity: opacity ?? this.opacity,
        backgroundFile: backgroundFile ?? this.backgroundFile,
        theme: theme ?? this.theme,
        lockNotification: lockNotification ?? this.lockNotification,
        fontScale: fontScale ?? this.fontScale,
        digits: digits ?? this.digits,
      );

  Map<String, Object?> toJson() => {
        'cityId': cityId,
        'cityName': cityName,
        'latitude': latitude,
        'longitude': longitude,
        'timeZone': timeZone,
        'prayerMethod': prayerMethod,
        'deposits': deposits.toList(),
        'layout': [for (final t in layout) t.toJson()],
        'opacity': opacity,
        'backgroundFile': backgroundFile,
        'theme': theme.name,
        'lockNotification': lockNotification,
        'fontScale': fontScale.name,
        'digits': digits.name,
      };

  String encode() => jsonEncode(toJson());
}
