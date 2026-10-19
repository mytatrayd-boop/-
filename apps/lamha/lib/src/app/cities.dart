import 'dart:convert';
import 'dart:math' as math;

/// مدن الاختيار اليدوي من `assets/cities.json` (منسوخة من apps/durur،
/// والإحداثيات من GeoNames برخصة CC BY 4.0).
class City {
  const City({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timeZone,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String timeZone;
}

List<City> parseCities(String source) {
  final j = jsonDecode(source) as Map<String, dynamic>;
  final tz = j['timeZone'] as String;
  return [
    for (final c in (j['cities'] as List).cast<Map<String, dynamic>>())
      City(
        id: c['id'] as String,
        name: c['name'] as String,
        latitude: (c['lat'] as num).toDouble(),
        longitude: (c['lon'] as num).toDouble(),
        timeZone: tz,
      ),
  ];
}

/// أقرب مدينة من القائمة للإحداثيات (مسافة الدائرة العظمى).
City nearestCity(List<City> cities, double lat, double lon) {
  double rad(double d) => d * math.pi / 180;
  double dist(City c) {
    final dLat = rad(c.latitude - lat);
    final dLon = rad(c.longitude - lon);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) *
            math.cos(rad(c.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * math.asin(math.sqrt(a));
  }

  return cities.reduce((a, b) => dist(a) <= dist(b) ? a : b);
}
