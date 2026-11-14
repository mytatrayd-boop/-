import 'geo_point.dart';
import 'simplify.dart';

/// الحد الافتراضي لطول الرابط (D6).
const int defaultMaxUrlLength = 2048;

/// عدد نقاط المنتصف الافتراضي (D6).
const int defaultMidWaypoints = 3;

String _coord(GeoPoint p) =>
    '${p.lat.toStringAsFixed(5)},${p.lng.toStringAsFixed(5)}';

/// رابط اتجاهات خرائط جوجل (Maps URLs) بنقاط قليلة. null لمسار فارغ
/// أو إن وُجدت نقطة غير صالحة. نقطة واحدة تعطي رابط بحث/موقع.
/// يُنقص نقاط المنتصف حتى لا يتجاوز الطول [maxLength]؛ إن لم يكفِ
/// حتى بلا منتصف يُرجع رابط البداية والنهاية فقط (أو null إن لم يتسع).
String? buildGoogleMapsUrl(
  List<GeoPoint> points, {
  int midWaypoints = defaultMidWaypoints,
  int maxLength = defaultMaxUrlLength,
}) {
  if (points.isEmpty || points.any((p) => !p.isValid)) return null;
  const base = 'https://www.google.com/maps';
  if (points.length == 1) {
    final u =
        '$base/search/?api=1&query=${Uri.encodeComponent(_coord(points.first))}';
    return u.length <= maxLength ? u : null;
  }
  for (var mid = midWaypoints < 0 ? 0 : midWaypoints; mid >= 0; mid--) {
    final s = simplifyToCount(points, mid + 2);
    final origin = _coord(s.first);
    final dest = _coord(s.last);
    final wp = s.sublist(1, s.length - 1).map(_coord).join('|');
    final sb = StringBuffer('$base/dir/?api=1')
      ..write('&origin=${Uri.encodeComponent(origin)}')
      ..write('&destination=${Uri.encodeComponent(dest)}');
    if (wp.isNotEmpty) sb.write('&waypoints=${Uri.encodeComponent(wp)}');
    final url = sb.toString();
    if (url.length <= maxLength) return url;
  }
  return null;
}
