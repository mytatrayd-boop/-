import '../core/app_failure.dart';
import 'youtube_link_parser.dart';

final _urlPattern = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// علامات ترقيم تلتصق بنهاية الرابط في الرسائل («...watch?v=ID.» أو «(الرابط)»).
final _trailingPunctuation = RegExp(r'''[.,;:!?)\]}>'"»”’،؛؟]+$''');

/// يستخرج أول رابط يوتيوب صالح من نص مشاركة (قد يحوي عنواناً قبل الرابط).
/// يرمي [AppFailure.invalidLink] إن لم يوجد. روابط القوائم تُرجَع كما هي
/// ليقرر المستدعي (غير مدعومة بعد).
ParsedLink parseSharedText(String text) {
  for (final m in _urlPattern.allMatches(text)) {
    try {
      return parseYoutubeLink(m.group(0)!.replaceFirst(_trailingPunctuation, ''));
    } on AppFailure {
      continue;
    }
  }
  // لا رابط ظاهراً: جرّب النص كله (مثلاً youtu.be/ID بلا بروتوكول).
  return parseYoutubeLink(text);
}
