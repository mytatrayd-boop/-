import 'dart:convert';

import '../engine/prayer.dart';
import '../engine/settings.dart';
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
    required this.visible,
    this.opacity = 100,
    this.backgroundFile,
  });

  factory LamhaSettings.defaults(City city, Set<String> depositIds) =>
      LamhaSettings(
        cityId: city.id,
        cityName: city.name,
        latitude: city.latitude,
        longitude: city.longitude,
        timeZone: city.timeZone,
        deposits: depositIds,
        visible: WidgetElement.values.toSet(),
      );

  factory LamhaSettings.fromJson(Map<String, dynamic> j) => LamhaSettings(
        cityId: j['cityId'] as String,
        cityName: j['cityName'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        timeZone: j['timeZone'] as String,
        prayerMethod: j['prayerMethod'] as String,
        deposits: (j['deposits'] as List).cast<String>().toSet(),
        visible: {
          for (final n in (j['visible'] as List).cast<String>())
            ...WidgetElement.values.where((e) => e.name == n),
        },
        opacity: j['opacity'] as int,
        backgroundFile: j['backgroundFile'] as String?,
      );

  static const prefsKey = 'settings';

  final String cityId;
  final String cityName;
  final double latitude;
  final double longitude;
  final String timeZone;
  final String prayerMethod;
  final Set<String> deposits;
  final Set<WidgetElement> visible;
  final int opacity;

  /// اسم ملف لقطة الخلفية داخل حاوية App Group (آيفون)، لا مسار كامل.
  final String? backgroundFile;

  /// [withBackground] = false في أندرويد، فيكون `background` في الجدول null.
  Settings toEngine({bool withBackground = true}) => Settings(
        latitude: latitude,
        longitude: longitude,
        cityName: cityName,
        timeZone: timeZone,
        prayerMethod: prayerMethod,
        deposits: deposits,
        visible: visible,
        opacity: opacity,
        background: withBackground ? backgroundFile : null,
      );

  LamhaSettings copyWith({
    String? cityId,
    String? cityName,
    double? latitude,
    double? longitude,
    String? timeZone,
    String? prayerMethod,
    Set<String>? deposits,
    Set<WidgetElement>? visible,
    int? opacity,
    String? backgroundFile,
  }) =>
      LamhaSettings(
        cityId: cityId ?? this.cityId,
        cityName: cityName ?? this.cityName,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        timeZone: timeZone ?? this.timeZone,
        prayerMethod: prayerMethod ?? this.prayerMethod,
        deposits: deposits ?? this.deposits,
        visible: visible ?? this.visible,
        opacity: opacity ?? this.opacity,
        backgroundFile: backgroundFile ?? this.backgroundFile,
      );

  Map<String, Object?> toJson() => {
        'cityId': cityId,
        'cityName': cityName,
        'latitude': latitude,
        'longitude': longitude,
        'timeZone': timeZone,
        'prayerMethod': prayerMethod,
        'deposits': deposits.toList(),
        'visible': [for (final e in visible) e.name],
        'opacity': opacity,
        'backgroundFile': backgroundFile,
      };

  String encode() => jsonEncode(toJson());
}
