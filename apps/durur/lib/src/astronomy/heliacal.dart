import 'heliacal_params.dart';
import 'horizon.dart';
import 'sidereal.dart';
import 'sun.dart';
import 'time.dart';

/// تاريخا الطلوع الفجري لسهيل والثريا لموقع وسنة (الميزة 5).
///
/// التاريخ يوم محلي بصيغة `DateTime.utc(y, m, d)` (صباح ذلك اليوم).
/// `null` = لا طلوع فجرياً في نافذة البحث لهذا الموقع (النجم لا يرتفع
/// فوق `h_star` أبداً، أو لا يغيب أبداً، أو الطلوع خارج النافذة).
class HeliacalDates {
  const HeliacalDates({required this.suhail, required this.thurayya});

  final DateTime? suhail;
  final DateTime? thurayya;
}

/// حساب الطلوع الفجري بمعيار قوس الرؤية (ARCHITECTURE §6، D9). Dart صافٍ.
///
/// لكل يوم محلي D: تُوجد لحظة t بين منتصف الليل والظهر (بالتوقيت الشمسي
/// المتوسط المحلي) يبلغ فيها الارتفاع الظاهري للنجم `h_star` وهو يطلع،
/// والنجم مرئي إن كان ارتفاع الشمس الحقيقي عند t ≤ −AV.
/// الطلوع = أول يوم مرئي بعد يوم غير مرئي داخل نافذة البحث.
///
/// الحساب لا يغيّر جدول المنطقة ولا عدّ الدرور (D10).
class HeliacalCalculator {
  const HeliacalCalculator();

  /// السنوات المدعومة: ΔT ثابتة (69 ث) ومعادلات Meeus منخفضة الدقة تكفي فيها.
  static const minYear = 2000;
  static const maxYear = 2100;

  static const _sampleMinutes = 10;
  static const _windowHours = 12;

  HeliacalDates compute({
    required double lat,
    required double lon,
    required int year,
  }) => HeliacalDates(
    suhail: risingDate(suhailParams, lat: lat, lon: lon, year: year),
    thurayya: risingDate(thurayyaParams, lat: lat, lon: lon, year: year),
  );

  /// تاريخ الطلوع الفجري للنجم في [params] أو null (انظر [HeliacalDates]).
  DateTime? risingDate(
    HeliacalParams params, {
    required double lat,
    required double lon,
    required int year,
  }) {
    _checkInputs(lat, lon, year);
    if (!_risesAndSets(params, lat, year)) return null;
    final start = params.windowStart.inYear(year);
    final end = params.windowEnd.inYear(year);
    bool? previous;
    for (
      var day = start;
      !day.isAfter(end);
      day = DateTime.utc(day.year, day.month, day.day + 1)
    ) {
      final visible = isVisible(params, lat: lat, lon: lon, date: day);
      if (visible && previous == false) return day;
      previous = visible;
    }
    return null;
  }

  /// هل يُرى النجم فجر اليوم المحلي [date] (يُستخدم التاريخ فقط)؟
  bool isVisible(
    HeliacalParams params, {
    required double lat,
    required double lon,
    required DateTime date,
  }) {
    _checkInputs(lat, lon, date.year);
    final t = starRisingMoment(params, lat: lat, lon: lon, date: date);
    if (t == null) return false;
    if (t.isInfinite) return true; // النجم فوق h_star منذ منتصف الليل.
    return sunAltitude(t, lat: lat, lon: lon) <= -params.arcusVisionis;
  }

  /// التاريخ اليولياني (UT) للحظة بلوغ النجم ارتفاعه الظاهري `h_star` طالعاً
  /// بين منتصف الليل والظهر محلياً يوم [date].
  /// `double.infinity` إن كان فوقه عند منتصف الليل، و null إن لم يبلغه.
  double? starRisingMoment(
    HeliacalParams params, {
    required double lat,
    required double lon,
    required DateTime date,
  }) {
    final midnightUt =
        julianDayUt(DateTime.utc(date.year, date.month, date.day)) -
        lon / 360.0;
    final position = params.star.positionAt(julianEphemerisDay(midnightUt));
    final target = trueAltitudeForApparent(params.starAltitude);
    double alt(double jd) => altitude(
      position: position,
      lat: lat,
      localSiderealTime: localSiderealTime(jd, lon),
    );

    const step = _sampleMinutes / 1440.0;
    const samples = _windowHours * 60 ~/ _sampleMinutes;
    var t0 = midnightUt;
    var a0 = alt(t0);
    if (a0 >= target) return double.infinity;
    for (var i = 1; i <= samples; i++) {
      final t1 = midnightUt + i * step;
      final a1 = alt(t1);
      if (a0 < target && a1 >= target) {
        var lo = t0;
        var hi = t1;
        for (var k = 0; k < 30; k++) {
          final mid = (lo + hi) / 2;
          if (alt(mid) < target) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        return (lo + hi) / 2;
      }
      t0 = t1;
      a0 = a1;
    }
    return null;
  }

  /// الارتفاع الحقيقي لمركز الشمس بالدرجات عند [jdUt].
  double sunAltitude(double jdUt, {required double lat, required double lon}) =>
      altitude(
        position: sunApparentPosition(julianEphemerisDay(jdUt)),
        lat: lat,
        localSiderealTime: localSiderealTime(jdUt, lon),
      );

  /// هل يطلع النجم ويغيب عند خط العرض هذا (بالنسبة لارتفاع h_star)؟
  bool _risesAndSets(HeliacalParams params, double lat, int year) {
    final jde = julianEphemerisDay(julianDayUt(DateTime.utc(year, 7, 1)));
    final dec = params.star.positionAt(jde).dec;
    final target = trueAltitudeForApparent(params.starAltitude);
    final maxAltitude = 90 - (lat - dec).abs();
    final minAltitude = (lat + dec).abs() - 90;
    return maxAltitude > target && minAltitude < target;
  }

  static void _checkInputs(double lat, double lon, int year) {
    if (!lat.isFinite || lat < -90 || lat > 90) {
      throw RangeError.range(lat, -90, 90, 'lat');
    }
    if (!lon.isFinite || lon < -180 || lon > 180) {
      throw RangeError.range(lon, -180, 180, 'lon');
    }
    RangeError.checkValueInInterval(year, minYear, maxYear, 'year');
  }
}
