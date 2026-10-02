// الوقت الفلكي (Meeus فصل 7 و10). Dart صافٍ.

/// التاريخ اليولياني لبداية حقبة J2000.0.
const double j2000 = 2451545.0;

/// فرق الزمن الديناميكي عن الزمن العالمي ΔT بالثواني، قيمة ثابتة تقريبية
/// لهذا العقد (ARCHITECTURE §6). خطأ دقيقة واحدة فيه لا يغيّر يوم الطلوع.
const double deltaTSeconds = 69.0;

/// التاريخ اليولياني (UT) للحظة [utc].
double julianDayUt(DateTime utc) =>
    2440587.5 + utc.toUtc().millisecondsSinceEpoch / 86400000.0;

/// التاريخ اليولياني بالزمن الديناميكي (JDE) من تاريخ يولياني UT.
double julianEphemerisDay(double jdUt) => jdUt + deltaTSeconds / 86400.0;

/// القرون اليوليانية منذ J2000.0.
double julianCenturies(double jd) => (jd - j2000) / 36525.0;

/// اللحظة UTC لتاريخ يولياني UT (عكس [julianDayUt]).
DateTime dateTimeFromJulianDay(double jdUt) =>
    DateTime.fromMillisecondsSinceEpoch(
      ((jdUt - 2440587.5) * 86400000).round(),
      isUtc: true,
    );
