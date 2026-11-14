/// نقطة مسار صافية (بلا اعتماد على مزوّد الخريطة).
class GeoPoint {
  const GeoPoint(this.lat, this.lng, {this.time, this.elevation});

  final double lat;
  final double lng;

  /// وقت الالتقاط (يُفضَّل UTC)؛ اختياري.
  final DateTime? time;

  /// الارتفاع بالمتر؛ اختياري.
  final double? elevation;

  bool get isValid =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.lat == lat &&
      other.lng == lng &&
      other.time == time &&
      other.elevation == elevation;

  @override
  int get hashCode => Object.hash(lat, lng, time, elevation);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}
