import 'angles.dart';
import 'sun.dart';
import 'time.dart';

// الفصول الأربعة الفلكية والبروج (DESIGN R3.2 وR3.1-10، D40 وD41). Dart صافٍ.
//
// - الاعتدالان والانقلابان: Meeus «Astronomical Algorithms» الفصل 27 (اللحظة
//   المتوسطة من الجدول 27.A ثم 24 حداً دورياً من الجدول 27.C)، ودقتها نحو
//   دقيقة واحدة في 1951–2050. تُحوَّل من TT إلى UT بـ [deltaTSeconds].
// - بدايات البروج الأخرى (كل 30° من طول الشمس الظاهري): حل عددي لطول الشمس
//   الظاهري بالدقة المنخفضة (Meeus الفصل 25، ~0.01°، أي نحو ربع ساعة).
//   الحمل والسرطان والميزان والجدي تُؤخذ من الفصل 27 نفسه، فتلتقي حدودها مع
//   حدود الفصول تماماً.

/// الأحداث الأربعة بترتيبها في السنة.
enum SolarEvent {
  /// الاعتدال الربيعي (طول الشمس 0°): يبدأ الربيع.
  marchEquinox(0),

  /// الانقلاب الصيفي (90°): يبدأ الصيف.
  juneSolstice(90),

  /// الاعتدال الخريفي (180°): يبدأ الخريف.
  septemberEquinox(180),

  /// الانقلاب الشتوي (270°): يبدأ الشتاء.
  decemberSolstice(270);

  const SolarEvent(this.longitude);

  /// طول الشمس الظاهري عند الحدث بالدرجات.
  final int longitude;
}

/// الفصل الفلكي، وحدث بدايته.
enum AstroSeason {
  spring(SolarEvent.marchEquinox),
  summer(SolarEvent.juneSolstice),
  autumn(SolarEvent.septemberEquinox),
  winter(SolarEvent.decemberSolstice);

  const AstroSeason(this.startEvent);

  final SolarEvent startEvent;

  /// الفصل التالي.
  AstroSeason get next => values[(index + 1) % values.length];
}

/// البروج الاستوائية الاثنا عشر بترتيبها من الحمل (0°).
enum ZodiacSign {
  aries,
  taurus,
  gemini,
  cancer,
  leo,
  virgo,
  libra,
  scorpio,
  sagittarius,
  capricorn,
  aquarius,
  pisces;

  /// طول الشمس الظاهري عند بداية البرج.
  int get longitude => index * 30;
}

// الجدول 27.A (السنوات 1000–3000): معاملات JDE0 بـ Y = (السنة − 2000) / 1000.
const _meanTerms = <SolarEvent, List<double>>{
  SolarEvent.marchEquinox: [
    2451623.80984, 365242.37404, 0.05169, -0.00411, -0.00057,
  ],
  SolarEvent.juneSolstice: [
    2451716.56767, 365241.62603, 0.00325, 0.00888, -0.00030,
  ],
  SolarEvent.septemberEquinox: [
    2451810.21715, 365242.01767, -0.11575, 0.00337, 0.00078,
  ],
  SolarEvent.decemberSolstice: [
    2451900.05952, 365242.74049, -0.06223, -0.00823, 0.00032,
  ],
};

// الجدول 27.C: (A، B بالدرجات، C بالدرجات لكل قرن).
const _periodic = <(double, double, double)>[
  (485, 324.96, 1934.136),
  (203, 337.23, 32964.467),
  (199, 342.08, 20.186),
  (182, 27.85, 445267.112),
  (156, 73.14, 45036.886),
  (136, 171.52, 22518.443),
  (77, 222.54, 65928.934),
  (74, 296.72, 3034.906),
  (70, 243.58, 9037.513),
  (58, 119.81, 33718.147),
  (52, 297.17, 150.678),
  (50, 21.02, 2281.226),
  (45, 247.54, 29929.562),
  (44, 325.15, 31555.956),
  (29, 60.93, 4443.417),
  (18, 155.12, 67555.328),
  (17, 288.79, 4562.452),
  (16, 198.04, 62894.029),
  (14, 199.76, 31436.921),
  (12, 95.39, 14577.848),
  (12, 287.11, 31931.756),
  (12, 320.81, 34777.259),
  (9, 227.73, 1222.114),
  (8, 15.45, 16859.074),
];

/// لحظة [event] في [year] بالتوقيت العالمي (UTC)، Meeus الفصل 27.
DateTime seasonEventUtc(int year, SolarEvent event) {
  final y = (year - 2000) / 1000;
  final c = _meanTerms[event]!;
  final jde0 = c[0] + y * (c[1] + y * (c[2] + y * (c[3] + y * c[4])));
  final t = julianCenturies(jde0);
  final w = 35999.373 * t - 2.47;
  final dl = 1 + 0.0334 * cosDeg(w) + 0.0007 * cosDeg(2 * w);
  var s = 0.0;
  for (final (a, b, cc) in _periodic) {
    s += a * cosDeg(b + cc * t);
  }
  final jde = jde0 + 0.00001 * s / dl;
  return dateTimeFromJulianDay(jde - deltaTSeconds / 86400.0);
}

/// لحظة بلوغ طول الشمس الظاهري [longitude] (درجات) قرب [year] (UTC):
/// القيمة تُعدّ من الاعتدال الربيعي لتلك السنة، فالسالبة (مثل −60 للدلو)
/// قبله في السنة نفسها. مضاعفات 90° من الفصل 27؛ وغيرها بحل عددي (الفصل 25).
DateTime sunLongitudeUtc(int year, int longitude) {
  final lon = longitude % 360;
  if (longitude >= 0 && longitude < 360 && lon % 90 == 0) {
    return seasonEventUtc(
      year,
      SolarEvent.values.firstWhere((e) => e.longitude == lon),
    );
  }
  // تقدير أولي: الشمس تقطع نحو 0.9856° يومياً بعد الاعتدال الربيعي.
  final march = julianDayUt(seasonEventUtc(year, SolarEvent.marchEquinox));
  var jd = march + longitude / 0.9856473;
  for (var i = 0; i < 8; i++) {
    final current = sunApparentLongitude(julianEphemerisDay(jd));
    var diff = lon - current;
    diff = (diff + 540) % 360 - 180; // إلى المدى (−180، 180]
    jd += diff / 0.9856473;
    if (diff.abs() < 1e-6) break;
  }
  return dateTimeFromJulianDay(jd);
}

/// تاريخ محلي (منتصف الليل، بلا منطقة زمنية) للحظة [utc]: بتوقيت الجهاز،
/// أو بإزاحة [utcOffset] إن أُعطيت (للاختبار ولمدن بعينها).
DateTime localDateOf(DateTime utc, {Duration? utcOffset}) {
  final t = utcOffset == null ? utc.toLocal() : utc.toUtc().add(utcOffset);
  return DateTime(t.year, t.month, t.day);
}

/// بداية فترة فلكية (فصل أو برج): اللحظة ويومها المحلي.
class AstroBoundary {
  const AstroBoundary(this.instant, this.day);

  /// اللحظة (UTC).
  final DateTime instant;

  /// يوم البداية المحلي (منتصف الليل)؛ يوم الحدث نفسه أول أيام الفترة.
  final DateTime day;
}

/// فترة فصل أو برج في سنة: من يوم بدايتها إلى اليوم السابق لبداية التالية.
class AstroPeriod<T> {
  const AstroPeriod({required this.value, required this.start, required this.end});

  final T value;
  final AstroBoundary start;

  /// بداية الفترة التالية (نهاية هذه، غير شاملة).
  final AstroBoundary end;

  /// آخر يوم شامل.
  DateTime get lastDay =>
      DateTime(end.day.year, end.day.month, end.day.day - 1);

  /// عدد الأيام (من يوم البداية إلى اليوم السابق لبداية التالية).
  int get days => DateTime.utc(end.day.year, end.day.month, end.day.day)
      .difference(DateTime.utc(start.day.year, start.day.month, start.day.day))
      .inDays;

  bool containsDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start.day) && d.isBefore(end.day);
  }
}

/// الفصول والبروج التي تغطي سنة ميلادية كاملة بتوقيت محلي واحد.
class AstroYear {
  AstroYear._(this.year, this.seasons, this.zodiac);

  /// يحسب [year] بتوقيت الجهاز، أو بإزاحة [utcOffset] ثابتة.
  factory AstroYear.compute(int year, {Duration? utcOffset}) {
    AstroBoundary at(DateTime utc) =>
        AstroBoundary(utc, localDateOf(utc, utcOffset: utcOffset));

    // الفصول: من الانقلاب الشتوي للسنة السابقة إلى الاعتدال الربيعي للتالية.
    final seasonBounds = <(AstroSeason, AstroBoundary)>[
      (AstroSeason.winter, at(seasonEventUtc(year - 1, SolarEvent.decemberSolstice))),
      for (final s in [
        AstroSeason.spring,
        AstroSeason.summer,
        AstroSeason.autumn,
        AstroSeason.winter,
      ])
        (s, at(seasonEventUtc(year, s.startEvent))),
      (AstroSeason.spring, at(seasonEventUtc(year + 1, SolarEvent.marchEquinox))),
    ];
    final seasons = [
      for (var i = 0; i < seasonBounds.length - 1; i++)
        AstroPeriod(
          value: seasonBounds[i].$1,
          start: seasonBounds[i].$2,
          end: seasonBounds[i + 1].$2,
        ),
    ];

    // البروج: من الجدي (270°) في السنة السابقة إلى الدلو في التالية.
    final zodiacBounds = <(ZodiacSign, AstroBoundary)>[
      (ZodiacSign.capricorn, at(sunLongitudeUtc(year - 1, 270))),
      // الدلو والحوت يبدآن قبل الاعتدال الربيعي في السنة نفسها.
      (ZodiacSign.aquarius, at(sunLongitudeUtc(year, 300 - 360))),
      (ZodiacSign.pisces, at(sunLongitudeUtc(year, 330 - 360))),
      for (final z in ZodiacSign.values.sublist(0, 10))
        (z, at(sunLongitudeUtc(year, z.longitude))),
      (ZodiacSign.aquarius, at(sunLongitudeUtc(year + 1, 300 - 360))),
    ];
    final zodiac = [
      for (var i = 0; i < zodiacBounds.length - 1; i++)
        AstroPeriod(
          value: zodiacBounds[i].$1,
          start: zodiacBounds[i].$2,
          end: zodiacBounds[i + 1].$2,
        ),
    ];
    return AstroYear._(year, List.unmodifiable(seasons), List.unmodifiable(zodiac));
  }

  final int year;

  /// خمس فترات: الشتاء (من السنة السابقة)، الربيع، الصيف، الخريف، الشتاء.
  final List<AstroPeriod<AstroSeason>> seasons;

  /// البروج من الجدي (السنة السابقة) إلى الجدي (آخر السنة).
  final List<AstroPeriod<ZodiacSign>> zodiac;

  /// الفصل الذي يحتوي اليوم المحلي [day] من هذه السنة.
  AstroPeriod<AstroSeason> seasonAt(DateTime day) =>
      seasons.firstWhere((p) => p.containsDay(day));

  /// البرج الذي يحتوي اليوم المحلي [day] من هذه السنة.
  AstroPeriod<ZodiacSign> zodiacAt(DateTime day) =>
      zodiac.firstWhere((p) => p.containsDay(day));
}
