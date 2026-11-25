class ResolvedAudio {
  const ResolvedAudio({
    required this.url,
    required this.title,
    this.author,
    this.duration,
    this.thumbnailUrl,
    this.expiresAt,
  });

  final Uri url;
  final String title;
  final String? author;
  final Duration? duration;
  final String? thumbnailUrl;

  /// وقت انتهاء صلاحية الرابط إن عُرف.
  final DateTime? expiresAt;
}
