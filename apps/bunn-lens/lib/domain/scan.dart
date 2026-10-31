enum ScanType { bean, coffee }

/// نتيجة فحص محفوظة محلياً. الملاحظات 3 بالضبط.
class Scan {
  Scan({
    required this.id,
    required this.type,
    required this.score,
    required List<String> notes,
    required this.imagePath,
    required this.createdAt,
    this.roasterName,
    this.price,
    this.isFavorite = false,
    this.promptVersion,
  }) : notes = List.unmodifiable(notes) {
    if (notes.length != 3) {
      throw ArgumentError.value(notes.length, 'notes', 'must be exactly 3');
    }
    if (score < 0 || score > 100) {
      throw RangeError.range(score, 0, 100, 'score');
    }
  }

  final int id;
  final ScanType type;
  final int score;
  final List<String> notes;
  final String imagePath;
  final DateTime createdAt;
  final String? roasterName;
  final double? price;
  final bool isFavorite;
  final String? promptVersion;
}

/// بيانات فحص جديد قبل الحفظ (بدون id، والصورة بايتات).
class NewScan {
  NewScan({
    required this.type,
    required this.score,
    required this.notes,
    required this.imageBytes,
    this.roasterName,
    this.price,
    this.promptVersion,
  });

  final ScanType type;
  final int score;
  final List<String> notes;
  final List<int> imageBytes;
  final String? roasterName;
  final double? price;
  final String? promptVersion;
}
