import '../../core/geo/geo_point.dart';
import '../../core/geo/gpx.dart';
import '../../core/geo/maps_url.dart';
import '../../data/share/share_service.dart';

/// نتيجة محاولة مشاركة/فتح: ok أو سبب الفشل (لتحدد الواجهة الرسالة).
enum ShareOutcome { ok, noRoute, noVideo, failed, openFailed }

/// منطق المشاركة (F10) خلف [ShareService]: لا واجهة ولا أصلي هنا.
class TripSharer {
  TripSharer(this._svc);
  final ShareService _svc;

  /// رابط خرائط جوجل (تقريبي) أو null إن لم يوجد مسار صالح.
  String? mapsUrl(List<GeoPoint> points) => buildGoogleMapsUrl(points);

  /// يشارك الفيديو (ملف videoPath) عبر قائمة النظام.
  Future<ShareOutcome> shareVideo(String? path) async {
    if (path == null || !await _svc.fileExists(path)) {
      return ShareOutcome.noVideo;
    }
    try {
      await _svc.shareFile(path, mimeType: 'video/mp4');
      return ShareOutcome.ok;
    } on ShareException {
      return ShareOutcome.failed;
    }
  }

  /// يشارك رابط خرائط جوجل نصاً؛ [message] يُبنى من نص الواجهة المترجم.
  Future<ShareOutcome> shareLink(
    List<GeoPoint> points,
    String Function(String url) message,
  ) async {
    final url = mapsUrl(points);
    if (url == null) return ShareOutcome.noRoute;
    try {
      await _svc.shareText(message(url));
      return ShareOutcome.ok;
    } on ShareException {
      return ShareOutcome.failed;
    }
  }

  /// يفتح الرابط في خرائط جوجل.
  Future<ShareOutcome> openInMaps(List<GeoPoint> points) async {
    final url = mapsUrl(points);
    if (url == null) return ShareOutcome.noRoute;
    return await _svc.openUrl(url) ? ShareOutcome.ok : ShareOutcome.openFailed;
  }

  /// يولّد GPX كاملاً ويشاركه كملف.
  Future<ShareOutcome> shareGpx(
    List<GeoPoint> points, {
    required String name,
    DateTime? time,
  }) async {
    if (points.where((p) => p.isValid).isEmpty) return ShareOutcome.noRoute;
    try {
      await _svc.shareGeneratedFile(
        buildGpx(points, name: name, time: time),
        '$name.gpx',
        mimeType: 'application/gpx+xml',
      );
      return ShareOutcome.ok;
    } on ShareException {
      return ShareOutcome.failed;
    }
  }

  /// يفتح الفيديو في مشغل النظام.
  Future<ShareOutcome> playVideo(String? path) async {
    if (path == null || !await _svc.fileExists(path)) {
      return ShareOutcome.noVideo;
    }
    return await _svc.openFile(path) ? ShareOutcome.ok : ShareOutcome.failed;
  }
}
