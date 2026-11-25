/// أنواع الفشل الموحّدة. الواجهة تحوّل النوع إلى رسالة مترجمة (لا نص هنا).
enum FailureKind {
  invalidLink,
  playlistNotSupported,
  extractionFailed,
  network,
  playbackFailed,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, [this.debugDetail]);

  final FailureKind kind;

  /// للتشخيص فقط؛ لا يُعرض للمستخدم ولا يجوز أن يحوي رموزاً.
  final String? debugDetail;

  @override
  String toString() => 'AppFailure($kind${debugDetail == null ? '' : ': $debugDetail'})';
}
