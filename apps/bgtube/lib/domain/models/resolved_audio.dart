class ResolvedAudio {
  const ResolvedAudio({
    required this.url,
    required this.title,
    this.author,
    this.duration,
    this.thumbnailUrl,
    this.expiresAt,
    this.httpHeaders = const {},
    this.sourceInfo,
    this.lateMetadata,
  });

  final Uri url;
  final String title;
  final String? author;
  final Duration? duration;
  final String? thumbnailUrl;

  /// وقت انتهاء صلاحية الرابط إن عُرف.
  final DateTime? expiresAt;

  /// ترويسات يجب أن يرسلها المشغّل مع طلبات [url] (عملياً User-Agent العميل
  /// الذي أصدر الرابط فقط). لا رموز دخول ولا كوكي أبداً (D4).
  final Map<String, String> httpHeaders;

  /// وصف تشخيصي قصير للمصدر (العميل/itag/الترميز)، بلا روابط ولا رموز.
  final String? sourceInfo;

  /// إن تأخرت البيانات الوصفية عن بدء التشغيل: تكتمل بها لاحقاً (أو null عند
  /// فشلها). null = البيانات أعلاه نهائية.
  final Future<AudioMetadata?>? lateMetadata;
}

/// بيانات وصفية تصل بعد بدء التشغيل.
class AudioMetadata {
  const AudioMetadata({required this.title, this.author, this.duration, this.thumbnailUrl});

  final String title;
  final String? author;
  final Duration? duration;
  final String? thumbnailUrl;
}
