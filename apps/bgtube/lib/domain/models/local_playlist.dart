/// قائمة محلية مسمّاة (على الجهاز فقط، لا تُرسل إلى يوتيوب).
class LocalPlaylist {
  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.totalDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int itemCount;

  /// مجموع المدد المعروفة فقط.
  final Duration totalDuration;
  final DateTime createdAt;
  final DateTime updatedAt;
}
