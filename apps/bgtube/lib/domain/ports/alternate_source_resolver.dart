import '../models/resolved_audio.dart';

/// مصدر بديل لنفس الفيديو من عميل استخراج آخر.
class AlternateSource {
  const AlternateSource({required this.audio, required this.client});

  final ResolvedAudio audio;

  /// اسم العميل (مثل `ANDROID_VR`)، وهو نفسه معامل `c` في الرابط.
  final String client;
}

/// يعيد استخراج الفيديو نفسه بعميل لم يُجرَّب بعد (تبديل العميل أثناء التشغيل
/// عند رفض googlevideo قطعة لاحقة بـ403، D24). مدخله معرّف الفيديو وأسماء
/// عملاء وبصمة الصيغة فقط: لا رموز دخول ولا كوكي (D4/D10).
abstract interface class AlternateSourceResolver {
  /// أول عميل غير موجود في [excludedClients] يعطي نفس الصيغة [itag] (إن عُرفت)،
  /// وإلا null حين لا يبقى عميل صالح.
  Future<AlternateSource?> resolveAlternate(
    String videoId, {
    required Set<String> excludedClients,
    String? itag,
  });
}
