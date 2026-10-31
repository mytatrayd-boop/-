/// مقهى محفوظ محلياً. الاسم إلزامي والإحداثيات اختيارية (معاً أو بلا).
class Cafe {
  const Cafe({required this.id, required this.name, required this.savedAt, this.lat, this.lng});

  final int id;
  final String name;
  final double? lat;
  final double? lng;
  final DateTime savedAt;

  bool get hasLocation => lat != null && lng != null;

  /// رابط خرائط قوقل بالإحداثيات (بلا مفتاح)؛ null إن لم يوجد موقع.
  Uri? get mapsUri => hasLocation ? mapsSearchUri(lat!, lng!) : null;
}

Uri mapsSearchUri(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

/// مقهى مع إحصاءات لشاشة «مقاهيّ المحفوظة».
class CafeSummary {
  const CafeSummary({required this.cafe, required this.scanCount, this.lastScore});

  final Cafe cafe;
  final int scanCount;
  final int? lastScore;
}
