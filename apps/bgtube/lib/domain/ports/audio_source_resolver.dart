import '../models/resolved_audio.dart';

/// يحلّ معرّف فيديو إلى رابط صوتي قابل للتشغيل.
///
/// مدخله `videoId` فقط: لا رموز دخول ولا كوكي ولا معلومات حساب (D4).
/// يرمي [AppFailure] عند الفشل.
abstract interface class AudioSourceResolver {
  Future<ResolvedAudio> resolve(String videoId);
}
