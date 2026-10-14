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
        // «وما» و«فهل»: واو العطف أو فاؤه قبل كلمة شائعة (الجذع لا يحذفهما
        // من كلمة قصيرة).
        if ((w.startsWith('و') || w.startsWith('ف')) &&
            arabicStopwords.contains(w.substring(1))) {
          continue;
        }
        if (seen.add(w)) words.add(w);
        if (words.length == SearchQuery.maxTerms) break;
      }
    }
    return AskQuery._(List.unmodifiable(words));
  }

  final List<String> words;

  bool get isEmpty => words.isEmpty;

  /// تعبير MATCH: كل كلمة تطابق `norm` أو جذعها `stem`، والكلمات بـ OR.
  /// والجذع يطابق بادئةً أيضاً («الهند» ← «هندي» في «للهندي»)، لأن الجذع
  /// الخفيف لا يحذف ياء النسبة (D8، D28).
  String toFtsMatch() => words
      .map((w) {
        final s = lightStem(w);
        return '(norm:"$w" OR stem:"$s" OR stem:"$s"*)';
      })
      .join(' OR ');

  /// عدد كلمات السؤال **المختلفة** الموجودة في [text] (الكلمة المطبَّعة أو
  /// جذعها يساوي جذع كلمة في النص)، لإعادة ترتيب المرشحين (D28).
  int matchedWords(String text) {
    final tokens = <String>{};
    final stems = <String>{};
    final norm = normalizeArabic(text);
    if (norm.isNotEmpty) {
      for (final t in norm.split(' ')) {
        tokens.add(t);
        stems.add(lightStem(t));
        // حرف جر متصل لا يحذفه الجذع الخفيف («لصديقك»، «لمعاوية»، «بالحلم»
        // يحذفها الجذع): لإعادة الترتيب فقط، لا للفهرس (D8، D28).
        if (t.length >= 4 && 'لبك'.contains(t[0])) {
          stems.add(lightStem(t.substring(1)));
        }
      }
    }
    var n = 0;
    for (final w in words) {
      final s = lightStem(w);
      if (tokens.contains(w) || stems.any((t) => t.startsWith(s))) n++;
    }
    return n;
  }

  /// هل في السؤال كلمة مميّزة من اسم [author] (بلا «ابن» و«أبو» ونحوهما)؟
  bool mentionsAuthor(String author) {
    if (author.isEmpty) return false;
    final names = AskQuery.fromQuestion(author).words;
    return names.any(words.contains);
  }

  /// استعلام بحث بالكلمات نفسها لتظليل التطابق في النصوص المعروضة.
  SearchQuery get highlightQuery => SearchQuery.parse(words.join(' '));
}
