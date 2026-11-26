/// مرجع مقطع يوتيوب: مدخل كل الشاشات إلى الطابور والقوائم المحلية (D27).
/// المعرّف وحده إلزامي؛ البيانات الوصفية تأتي جاهزة من الشاشة إن عُرفت، أو
/// تُثرى لاحقاً من الاستخراج.
class VideoRef {
  const VideoRef({required this.videoId, this.title, this.author, this.duration, this.thumbUrl});

  final String videoId;
  final String? title;
  final String? author;
  final Duration? duration;
  final String? thumbUrl;

  VideoRef copyWith({String? title, String? author, Duration? duration, String? thumbUrl}) => VideoRef(
        videoId: videoId,
        title: title ?? this.title,
        author: author ?? this.author,
        duration: duration ?? this.duration,
        thumbUrl: thumbUrl ?? this.thumbUrl,
      );

  @override
  bool operator ==(Object other) =>
      other is VideoRef &&
      other.videoId == videoId &&
      other.title == title &&
      other.author == author &&
      other.duration == duration &&
      other.thumbUrl == thumbUrl;

  @override
  int get hashCode => Object.hash(videoId, title, author, duration, thumbUrl);

  @override
  String toString() => 'VideoRef($videoId)';
}
