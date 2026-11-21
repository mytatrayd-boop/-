import 'package:timezone/timezone.dart' as tz;

import 'prayer.dart';

/// الأذان عند كل صلاة (طلب المالك ١١/١١/٢٠٢٦، DECISIONS ٢٨): تنبيه صوتي في وقت الصلاة، لكل صلاة مفتاحها،
/// بصوت أذان كامل (أندرويد) أو تكبيرتين أو صامت. الحساب هنا نقي بلا منصة؛ الجدولة الفعلية في
/// `app/adhan_service.dart`.

/// صوت التنبيه. أسماؤها تُحفظ في الإعدادات فلا تُغيَّر.
enum AdhanSound {
  /// الأذان كاملاً (٣:٠٥). أندرويد فقط: حد آبل لصوت الإشعار ٣٠ ثانية، فيُستبدل في آيفون بالتكبيرتين.
  full,

  /// تكبيرتان (٢٣٫٦ ثانية): تصلح للمنصتين.
  takbeer,

  /// إشعار بلا صوت.
  silent;

  static AdhanSound byName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => full);

  /// الصوت الفعلي على المنصة: آيفون لا يشغّل الأذان الكامل في الإشعار.
  AdhanSound forPlatform({required bool ios}) => ios && this == full ? takbeer : this;
}

/// الصلوات التي لها أذان (الشروق ليس صلاة).
const adhanPrayers = [
  PrayerName.fajr,
  PrayerName.dhuhr,
  PrayerName.asr,
  PrayerName.maghrib,
  PrayerName.isha,
];

/// أقصى عدد تنبيهات تُجدوَل معاً: آيفون يسمح بـ٦٤ إشعاراً معلّقاً، فنكتفي بـ٦٠ (١٢ يوماً × ٥ صلوات)
/// في المنصتين، وتتجدد القائمة كلما فُتح التطبيق أو تغيرت الإعدادات.
const adhanMaxEvents = 60;

/// إعدادات الأذان المحفوظة. مطفأ افتراضياً (يحتاج إذن الإشعارات).
class AdhanSettings {
  const AdhanSettings({
    this.enabled = false,
    this.prayers = const {
      PrayerName.fajr,
      PrayerName.dhuhr,
      PrayerName.asr,
      PrayerName.maghrib,
      PrayerName.isha,
    },
    this.sound = AdhanSound.full,
  });

  factory AdhanSettings.fromJson(Object? j) {
    if (j is! Map) return const AdhanSettings();
    final names = (j['prayers'] as List?)?.cast<String>();
    return AdhanSettings(
      enabled: j['enabled'] as bool? ?? false,
      prayers: names == null
          ? const AdhanSettings().prayers
          : {
              for (final p in adhanPrayers)
                if (names.contains(p.name)) p,
            },
      sound: AdhanSound.byName(j['sound'] as String?),
    );
  }

  /// المفتاح العام: إطفاؤه يلغي كل التنبيهات.
  final bool enabled;

  /// الصلوات المفعّل أذانها (من [adhanPrayers]).
  final Set<PrayerName> prayers;
  final AdhanSound sound;

  AdhanSettings copyWith({bool? enabled, Set<PrayerName>? prayers, AdhanSound? sound}) =>
      AdhanSettings(
        enabled: enabled ?? this.enabled,
        prayers: prayers ?? this.prayers,
        sound: sound ?? this.sound,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'prayers': [for (final p in adhanPrayers) if (prayers.contains(p)) p.name],
        'sound': sound.name,
      };

  @override
  bool operator ==(Object other) =>
      other is AdhanSettings &&
      other.enabled == enabled &&
      other.sound == sound &&
      other.prayers.length == prayers.length &&
      other.prayers.containsAll(prayers);

  @override
  int get hashCode => Object.hash(enabled, sound, Object.hashAllUnordered(prayers));
}

/// تنبيه واحد مجدوَل.
class AdhanEvent {
  const AdhanEvent({required this.id, required this.prayer, required this.time});

  /// معرّف ثابت للصلاة واليوم: `yyyyMMdd * 10 + ترتيب الصلاة` (أقل من 2³¹)، فلا يتكرر ولا يتغير بين التشغيلات.
  final int id;
  final PrayerName prayer;

  /// وقت الصلاة بتوقيت مدينة المستخدم.
  final tz.TZDateTime time;

  String get title => 'أذان ${prayer.arabic}';

  /// النص تحت العنوان؛ [city] اسم المدينة.
  String body(String city) => 'حان الآن موعد صلاة ${prayer.arabic} · $city';

  @override
  String toString() => 'AdhanEvent($id, ${prayer.name}, $time)';
}

/// معرّف تنبيه صلاة [prayer] في اليوم المحلي [date].
int adhanId(DateTime date, PrayerName prayer) =>
    (date.year * 10000 + date.month * 100 + date.day) * 10 + prayer.index;

/// التنبيهات القادمة بعد [now]: الصلوات المفعّلة بترتيبها الزمني، حتى [max] تنبيهاً. فارغة إن كان الأذان
/// مطفأً أو بلا صلوات.
List<AdhanEvent> planAdhan(
  PrayerCalculator calc,
  DateTime now,
  AdhanSettings settings, {
  int max = adhanMaxEvents,
}) {
  if (!settings.enabled || settings.prayers.isEmpty || max <= 0) return const [];
  final local = tz.TZDateTime.from(now, calc.location);
  final out = <AdhanEvent>[];
  // الأيام التي نمرّ بها تكفي لملء [max] ولو فُعِّلت صلاة واحدة.
  for (var d = 0; out.length < max && d < max + 2; d++) {
    final day = DateTime(local.year, local.month, local.day + d);
    final times = calc.forDate(day);
    for (final p in adhanPrayers) {
      if (!settings.prayers.contains(p)) continue;
      final t = times[p];
      if (!t.isAfter(local)) continue;
      out.add(AdhanEvent(id: adhanId(day, p), prayer: p, time: t));
      if (out.length >= max) break;
    }
  }
  return out;
}

/// بصمة التنبيهات والصوت والمدينة: تُعاد الجدولة عند تغيّرها فقط، لا مع كل حفظ للودجت.
String adhanSignature(List<AdhanEvent> events, AdhanSound sound, String city) =>
    '${sound.name}|$city|${[for (final e in events) '${e.id}@${e.time.millisecondsSinceEpoch}'].join(',')}';
