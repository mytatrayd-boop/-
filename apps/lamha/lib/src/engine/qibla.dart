import 'dart:math' as math;

/// اتجاه القبلة: زاوية الدائرة العظمى من الشمال الحقيقي باتجاه عقارب الساعة.

const kaabaLatitude = 21.4225;
const kaabaLongitude = 39.8262;

/// أسماء الاتجاهات الثمانية بدءاً من الشمال باتجاه عقارب الساعة.
const directionNames = [
  'شمال',
  'شمال شرق',
  'شرق',
  'جنوب شرق',
  'جنوب',
  'جنوب غرب',
  'غرب',
  'شمال غرب',
];

/// زاوية القبلة بالدرجات في [0، 360).
double qiblaDegrees(double latitude, double longitude) {
  const r = math.pi / 180;
  final phi = latitude * r;
  final phiK = kaabaLatitude * r;
  final dLon = (kaabaLongitude - longitude) * r;
  final y = math.sin(dLon);
  final x = math.cos(phi) * math.tan(phiK) - math.sin(phi) * math.cos(dLon);
  final deg = math.atan2(y, x) / r;
  return (deg % 360 + 360) % 360;
}

/// اسم الاتجاه العربي لزاوية [degrees] (ثمانية اتجاهات، كل منها 45°).
String directionName(double degrees) {
  final i = (((degrees % 360) + 360) % 360 / 45).round() % 8;
  return directionNames[i];
}
