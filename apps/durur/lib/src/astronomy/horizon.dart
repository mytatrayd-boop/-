import 'angles.dart';

/// الارتفاع الهندسي (بلا انكسار) لجرم فوق الأفق بالدرجات:
/// sin h = sin φ sin δ + cos φ cos δ cos H، و H = LST − α.
double altitude({
  required Equatorial position,
  required double lat,
  required double localSiderealTime,
}) {
  final hourAngle = localSiderealTime - position.ra;
  return asinDeg(
    sinDeg(lat) * sinDeg(position.dec) +
        cosDeg(lat) * cosDeg(position.dec) * cosDeg(hourAngle),
  );
}

/// الانكسار الجوي بالدرجات لارتفاع حقيقي [trueAltitude] (صيغة Sæmundsson،
/// Meeus 16.4، ضغط 1010 ملي بار وحرارة 10° م). صالحة فوق −2° تقريباً.
double saemundssonRefraction(double trueAltitude) {
  final arcMinutes = 1.02 / tanDeg(trueAltitude + 10.3 / (trueAltitude + 5.11));
  return arcMinutes / 60;
}

/// الارتفاع الحقيقي الذي يظهر عنده الجرم على ارتفاع [apparentAltitude]
/// (حل h + R(h) = h_app بالتكرار).
double trueAltitudeForApparent(double apparentAltitude) {
  var h = apparentAltitude;
  for (var i = 0; i < 50; i++) {
    final next = apparentAltitude - saemundssonRefraction(h);
    if ((next - h).abs() < 1e-9) return next;
    h = next;
  }
  return h;
}
