import 'distance.dart';
import 'geo_point.dart';
import 'simplify.dart';

/// الحد الافتراضي لطول الرابط (D6).
const int defaultMaxUrlLength = 2048;

/// وسيلة التنقل الافتراضية في الرابط (D6).
const String defaultTravelMode = 'driving';

/// عدد نقاط المنتصف الافتراضي (D6).
const int defaultMidWaypoints = 3;

/// أقل مسافة (م) بين البداية والنهاية لبناء رابط اتجاهات؛ دونها تفشل خرائط
/// جوجل بـ«يتعذّر العثور على طريق» فيُستعمل رابط موقع (FEEDBACK 6).
const double minDirectionsMeters = 50;

/// 6 خانات عشرية (~11 سم).
String _coord(GeoPoint p) =>
    '${p.lat.toStringAsFixed(6)},${p.lng.toStringAsFixed(6)}';

/// نوع رابط خرائط جوجل المبني.
enum MapsLinkKind { route, location }

class MapsLink {
  const MapsLink(this.url, this.kind);
  final String url;
  final MapsLinkKind kind;
}

/// هل في المسار حركة فعلية؟ الحكم بأبعد نقطة عن البداية (أقصى بُعد) أو بطول
/// المسار الكلي، لا بالبداية/النهاية فقط (رحلة دائرية بداية≈نهاية حركة
/// حقيقية، FEEDBACK 11). false لأقل من نقطتين أو إن وُجدت نقطة غير صالحة.
bool hasMovement(
  List<GeoPoint> points, {
  double minMeters = minDirectionsMeters,
}) {
  if (points.length < 2 || points.any((p) => !p.isValid)) return false;
  var maxFromStart = 0.0;
  for (final p in points) {
    final d = haversineMeters(points.first, p);
    if (d > maxFromStart) maxFromStart = d;
  }
  return maxFromStart >= minMeters || pathLengthMeters(points) >= 4 * minMeters;
}

/// يبني الرابط المناسب: اتجاهات للمسار ذي الحركة الكافية، وإلا رابط موقع
/// لآخر نقطة. null: لا نقاط/نقطة غير صالحة/الرابط أطول من الحد.
MapsLink? buildMapsLink(
  List<GeoPoint> points, {
  int midWaypoints = defaultMidWaypoints,
  int maxLength = defaultMaxUrlLength,
  String travelMode = defaultTravelMode,
  double minMeters = minDirectionsMeters,
}) {
  if (points.isEmpty || points.any((p) => !p.isValid)) return null;
  const base = 'https://www.google.com/maps';
  if (!hasMovement(points, minMeters: minMeters)) {
    final u =
        '$base/search/?api=1&query=${Uri.encodeComponent(_coord(points.last))}';
    return u.length <= maxLength ? MapsLink(u, MapsLinkKind.location) : null;
  }
  final url = _directions(points, base, midWaypoints, maxLength, travelMode);
  return url == null ? null : MapsLink(url, MapsLinkKind.route);
}

/// رابط اتجاهات خرائط جوجل (Maps URLs) بنقاط قليلة. null لمسار فارغ
/// أو إن وُجدت نقطة غير صالحة. نقطة واحدة تعطي رابط بحث/موقع.
/// يُنقص نقاط المنتصف حتى لا يتجاوز الطول [maxLength]؛ إن لم يكفِ
/// حتى بلا منتصف يُرجع رابط البداية والنهاية فقط (أو null إن لم يتسع).
String? buildGoogleMapsUrl(
  List<GeoPoint> points, {
  int midWaypoints = defaultMidWaypoints,
  int maxLength = defaultMaxUrlLength,
  String travelMode = defaultTravelMode,
}) => buildMapsLink(
  points,
  midWaypoints: midWaypoints,
  maxLength: maxLength,
  travelMode: travelMode,
)?.url;

String? _directions(
  List<GeoPoint> points,
  String base,
  int midWaypoints,
  int maxLength,
  String travelMode,
) {
  for (var mid = midWaypoints < 0 ? 0 : midWaypoints; mid >= 0; mid--) {
    var s = simplifyToCount(points, mid + 2);
    // رحلة دائرية: origin==destination تقبلها خرائط جوجل مع waypoints، لكن
    // عند الشك (بلا منتصف) نجعل النهاية نقطة قبل الأخيرة فلا يتطابقان.
    if (s.length >= 2 && _coord(s.first) == _coord(s.last)) {
      if (s.length == 2) {
        s = [points.first, _farthestFrom(points, points.first)];
      }
    }
    final origin = _coord(s.first);
    final dest = _coord(s.last);
    final wp = s.sublist(1, s.length - 1).map(_coord).join('|');
    final sb = StringBuffer('$base/dir/?api=1')
      ..write('&origin=${Uri.encodeComponent(origin)}')
      ..write('&destination=${Uri.encodeComponent(dest)}');
    if (wp.isNotEmpty) sb.write('&waypoints=${Uri.encodeComponent(wp)}');
    sb.write('&travelmode=${Uri.encodeComponent(travelMode)}');
    final url = sb.toString();
    if (url.length <= maxLength) return url;
  }
  return null;
}

GeoPoint _farthestFrom(List<GeoPoint> pts, GeoPoint from) {
  var best = pts.last;
  var bestD = -1.0;
  for (final p in pts) {
    final d = haversineMeters(from, p);
    if (d > bestD) {
      bestD = d;
      best = p;
    }
  }
  return best;
}
