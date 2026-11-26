import 'video_ref.dart';

/// صف في سجل التشغيل المحلي (الميزة 5، D5). [id] للحذف من السجل.
class HistoryEntry {
  const HistoryEntry({required this.id, required this.ref, required this.playedAt});

  final int id;
  final VideoRef ref;
  final DateTime playedAt;

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry && other.id == id && other.ref == ref && other.playedAt == playedAt;

  @override
  int get hashCode => Object.hash(id, ref, playedAt);
}
