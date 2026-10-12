/// تحويل سؤال «اسأل الأديب» إلى استعلام استرجاع محلي (ARCHITECTURE §7):
/// تطبيع، حذف الكلمات الشائعة، جذع خفيف، و**OR** بين الكلمات (لا AND كالبحث)
/// مع ترتيب bm25. Dart صافٍ.
library;

import '../text/arabic_normalizer.dart';
import '../text/arabic_stopwords.dart';
import '../text/light_stemmer.dart';
import '../text/search_query.dart';

/// حدود السؤال (DESIGN §12.2، الخادم: MAX_QUESTION_CHARS).
const maxQuestionChars = 500;
const minQuestionChars = 3;

/// يزيل محارف التحكم (عدا السطر الجديد والجدولة) التي يرفضها الخادم، ويحذف
/// المسافات الطرفية.
String cleanQuestion(String raw) =>
    raw.replaceAll(RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]'), ' ').trim();

class AskQuery {
  const AskQuery._(this.words);

  /// يحلّل [question]: الكلمات المطبَّعة بلا الشائعة ولا المكررة ولا ما دون
  /// حرفين، بحد أقصى [SearchQuery.maxTerms].
  factory AskQuery.fromQuestion(String question) {
    final norm = normalizeArabic(question);
    final words = <String>[];
    final seen = <String>{};
    if (norm.isNotEmpty) {
      for (final w in norm.split(' ')) {
        if (w.length < 2 || arabicStopwords.contains(w)) continue;
        // «والكرم» و«فالكرم» بعد حذف السابقة قد تكون كلمة شائعة («وما»).
        if (arabicStopwords.contains(lightStem(w))) continue;
        if (seen.add(w)) words.add(w);
        if (words.length == SearchQuery.maxTerms) break;
      }
    }
    return AskQuery._(List.unmodifiable(words));
  }

  final List<String> words;

  bool get isEmpty => words.isEmpty;

  /// تعبير MATCH: كل كلمة تطابق `norm` أو جذعها `stem`، والكلمات بـ OR.
  String toFtsMatch() =>
      words.map((w) => '(norm:"$w" OR stem:"${lightStem(w)}")').join(' OR ');

  /// استعلام بحث بالكلمات نفسها لتظليل التطابق في النصوص المعروضة.
  SearchQuery get highlightQuery => SearchQuery.parse(words.join(' '));
}
