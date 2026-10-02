import 'dart:math' as math;

import '../domain/city.dart';

/// متوسط نصف قطر الأرض بالكيلومتر (IUGG).
const double earthRadiusKm = 6371.0088;

/// أبعد مسافة مقبولة بين المستخدم وأقرب مدينة في القائمة (D11).
/// أبعد منها ← «منطقتك خارج نطاق الجداول».
const double maxNearestCityKm = 250;

/// المسافة على سطح الكرة (هافرساين) بالكيلومتر بين نقطتين بالدرجات.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}

/// أقرب مدينة ومسافتها.
class NearestCity {
  const NearestCity(this.city, this.distanceKm);

  final City city;
  final double distanceKm;

  /// هل المدينة ضمن الحد المقبول ([maxNearestCityKm])؟
  bool get inRange => distanceKm <= maxNearestCityKm;
}

/// أقرب مدينة في [cities] إلى النقطة، أو null إن كانت القائمة فارغة.
/// عند التساوي تُختار الأسبق في القائمة (نتيجة ثابتة).
NearestCity? findNearestCity(List<City> cities, double lat, double lon) {
  NearestCity? best;
  for (final city in cities) {
    final d = haversineKm(lat, lon, city.lat, city.lon);
    if (best == null || d < best.distanceKm) best = NearestCity(city, d);
  }
  return best;
}
