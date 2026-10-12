/// واجهة محرك النطق (TTS) وواجهة جلسة الوسائط (الإشعار وشاشة القفل والتركيز
/// الصوتي)، حتى يُستبدلا بمحاكاة في الاختبارات (ARCHITECTURE §10، §14).
/// Dart صافٍ.
library;

/// صوت من أصوات الجهاز.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  /// معرّف الصوت في المحرك (يُحفظ في الإعدادات).
  final String name;

  /// وسم اللغة، مثل `ar-EG` أو `ar`.
  final String locale;

  /// رمز البلد بحروف كبيرة من وسم اللغة (`EG`)، أو null.
  String? get region {
    final parts = locale.replaceAll('_', '-').split('-');
    for (final p in parts.skip(1)) {
      if (p.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(p)) {
        return p.toUpperCase();
      }
    }
    return null;
  }

  static bool isArabicLocale(String locale) {
    final l = locale.toLowerCase().replaceAll('_', '-');
    return l == 'ar' || l.startsWith('ar-');
  }

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);

  @override
  String toString() => 'TtsVoice($name, $locale)';
}

/// نتيجة نطق مقطع.
enum SpeakResult {
  /// انتهى النطق.
  done,

  /// أُوقف بـ [TtsEngine.stop].
  cancelled,

  /// خطأ في المحرك.
  error,
}

abstract interface class TtsEngine {
  /// الأصوات العربية المتاحة على الجهاز (مرتبة)، أو قائمة فارغة.
  Future<List<TtsVoice>> arabicVoices();

  /// [voice] null = الصوت العربي الافتراضي للمحرك. [speed] من 0.5 إلى 2
  /// (1 = السرعة العادية).
  Future<void> configure({TtsVoice? voice, required double speed});

  /// ينطق [text] ويكتمل عند انتهائه أو إيقافه أو فشله.
  Future<SpeakResult> speak(String text);

  /// يوقف النطق الجاري (يكتمل [speak] الجاري بـ [SpeakResult.cancelled]).
  Future<void> stop();

  /// يفتح إعدادات «تحويل النص إلى كلام» في النظام. false إن تعذّر.
  Future<bool> openInstallSettings();
}

/// ما يُعرض في الإشعار وشاشة القفل.
class NowPlaying {
  const NowPlaying({
    required this.id,
    required this.chapterTitle,
    required this.bookTitle,
    required this.author,
  });

  /// معرّف الفقرة الجارية.
  final String id;
  final String chapterTitle;
  final String bookTitle;
  final String author;

  @override
  bool operator ==(Object other) =>
      other is NowPlaying &&
      other.id == id &&
      other.chapterTitle == chapterTitle &&
      other.bookTitle == bookTitle &&
      other.author == author;

  @override
  int get hashCode => Object.hash(id, chapterTitle, bookTitle, author);
}

/// حالة الجلسة كما تُرسل إلى الإشعار.
class MediaSessionState {
  const MediaSessionState({
    required this.playing,
    required this.loading,
    required this.nowPlaying,
  });

  final bool playing;
  final bool loading;
  final NowPlaying nowPlaying;

  @override
  bool operator ==(Object other) =>
      other is MediaSessionState &&
      other.playing == playing &&
      other.loading == loading &&
      other.nowPlaying == nowPlaying;

  @override
  int get hashCode => Object.hash(playing, loading, nowPlaying);
}

/// أوامر تصل من الإشعار وشاشة القفل وأزرار السماعة والنظام.
enum MediaCommand {
  play,
  pause,
  next,
  previous,
  stop,

  /// بدء مقاطعة (مكالمة أو فقد التركيز الصوتي).
  interruptionBegan,

  /// انتهت المقاطعة ويمكن الاستئناف.
  interruptionEnded,

  /// انتهت المقاطعة ولا يُستأنف (فقد التركيز نهائياً).
  interruptionEndedNoResume,

  /// فصل السماعة.
  becomingNoisy,

  /// الضغط على الإشعار: افتح المشغّل الكامل.
  openPlayer,
}

abstract interface class MediaSession {
  /// يبدأ الخدمة الأمامية (مرة) ويطلب التركيز الصوتي (في كل استدعاء). يعيد
  /// false إن رُفض التركيز (مثلاً مكالمة جارية). يرمي إن تعذّر بدء الخدمة.
  Future<bool> activate();

  /// يحدّث الإشعار وأزرار التحكم.
  void update(MediaSessionState state);

  /// ينهي الجلسة: يخفي الإشعار ويوقف الخدمة ويترك التركيز الصوتي.
  Future<void> deactivate();

  Stream<MediaCommand> get commands;
}
