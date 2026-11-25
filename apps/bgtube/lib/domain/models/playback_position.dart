/// آخر موضع محفوظ لفيديو.
class PlaybackPosition {
  const PlaybackPosition({
    required this.videoId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String videoId;
  final Duration position;

  /// صفر إن كانت المدة مجهولة وقت الحفظ.
  final Duration duration;
  final DateTime updatedAt;
}
