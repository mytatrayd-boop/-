/// اختيار الفقرات المرسلة إلى الخادم (ARCHITECTURE §7، §8.4، D28): إعادة
/// ترتيب المرشحين بعدد كلمات السؤال المطابقة ثم bm25، وأفضل 6 فقرات، كل فقرة
/// ≤ 1,500 حرف والمجموع ≤ 8,000، والفقرة الطويلة تُقص على حدود الكلمات حول
/// أول تطابق، والفقرة التمهيدية تُرسل معها الفقرة التالية. Dart صافٍ.
library;

import '../text/search_query.dart';
import 'ask_query.dart';

/// حدود الخادم (worker/wrangler.jsonc: MAX_PASSAGES وMAX_PASSAGE_CHARS
/// وMAX_PASSAGES_TOTAL_CHARS، وحد عنوان الكتاب والباب 200).
const maxPassages = 6;
const maxPassageChars = 1500;
const maxPassagesTotalChars = 8000;
const maxTitleChars = 200;

/// أقل نص يستحق الإرسال حين يضيق ما بقي من المجموع.
const minPassageChars = 200;

/// عدد الفقرات التي يعيدها المسترجع بعد إعادة الترتيب (الاختيار قد يتخطى
/// بعضها).
const retrieveLimit = maxPassages * 2;

/// عدد المرشحين من FTS5 (bm25) قبل إعادة الترتيب (D28).
const candidateCount = 80;

/// فقرة أقصر من هذا (مثل شطر أو «وقال الشاعر:») لا تُرشَّح وحدها (D28).
const minCandidateChars = 50;

/// فقرة تمهيدية: تنتهي بنقطتين (أو فاصلة) فقولها في الفقرة التالية، مثل
/// «وقال الشاعر:» أو «قال بعض الحكماء في ذلك:».
bool isIntroParagraph(String text) {
  final t = text.trimRight();
  return t.endsWith(':') || t.endsWith('،') || t.endsWith(',');
}

/// يعيد ترتيب [candidates] (مرتبة bm25): عدد كلمات السؤال المختلفة المطابقة
/// أولاً ثم bm25، ويستبعد القصيرة جداً غير التمهيدية.
List<LocalParagraph> rerankCandidates(
  List<LocalParagraph> candidates,
  AskQuery query,
) {
  final scored = <(LocalParagraph, int, int)>[];
  for (var i = 0; i < candidates.length; i++) {
    final p = candidates[i];
    final short = p.text.trim().length < minCandidateChars;
    if (short && !(isIntroParagraph(p.text) && p.next != null)) continue;
    // التمهيدية تُقاس مع ما يليها، لأنهما يُرسلان معاً.
    final text = isIntroParagraph(p.text) && p.next != null
        ? '${p.text} ${p.next!.text}'
        : p.text;
    scored.add((p, query.matchedWords(text), i));
  }
  scored.sort((a, b) => a.$2 != b.$2 ? b.$2 - a.$2 : a.$3 - b.$3);
  return [for (final s in scored) s.$1];
}

/// فقرة من القاعدة المحلية بنصها الكامل الأصلي (بالتشكيل).
class LocalParagraph {
  const LocalParagraph({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.text,
    this.next,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final String text;

  /// الفقرة التالية في الباب نفسه إن كانت هذه تمهيدية (وإلا null).
  final LocalParagraph? next;
}

/// فقرة مختارة: الأصل المحلي الكامل، والجزء المرسل منه.
class AskPassage {
  const AskPassage({required this.paragraph, required this.sentText});

  final LocalParagraph paragraph;

  /// جزء متصل من [LocalParagraph.text] (أو كله) لا يتجاوز الحدود.
  final String sentText;

  String get id => paragraph.id;

  /// جسم الفقرة في طلب `POST /v1/ask` (ARCHITECTURE §8.1).
  Map<String, Object?> toJson() => {
    'id': paragraph.id,
    'book': clipTitle(paragraph.bookTitle),
    'chapter': clipTitle(paragraph.chapterTitle),
    'text': sentText,
  };
}

/// محارف التحكم التي يرفضها الخادم (عدا \n و\t).
final _control = RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]');

String _clean(String s) => s.replaceAll(_control, ' ');

/// عنوان نظيف بطول ≤ 200 (الخادم يرفض الأطول والفارغ).
String clipTitle(String title) {
  final t = _clean(title).trim();
  if (t.isEmpty) return '-';
  return t.length <= maxTitleChars ? t : t.substring(0, maxTitleChars).trim();
}

bool _isSpace(int c) => c == 0x20 || c == 0x0A || c == 0x09 || c == 0x0D;

/// جزء من [text] طوله ≤ [cap] يبدأ قبل [matchStart] بنحو ربع الحد، مقصوص
/// على حدود الكلمات (لا يبدأ ولا ينتهي بنصف كلمة إن وُجدت مسافة).
String excerptAround(String text, int matchStart, int cap) {
  if (text.length <= cap) return text;
  var start = matchStart - cap ~/ 4;
  if (start + cap > text.length) start = text.length - cap;
  if (start < 0) start = 0;
  var end = start + cap;
  if (start > 0 && !_isSpace(text.codeUnitAt(start - 1))) {
    for (var i = start; i < end && i <= matchStart; i++) {
      if (_isSpace(text.codeUnitAt(i))) {
        start = i + 1;
        break;
      }
    }
  }
  if (end < text.length && !_isSpace(text.codeUnitAt(end))) {
    for (var i = end - 1; i > start; i--) {
      if (_isSpace(text.codeUnitAt(i))) {
        end = i;
        break;
      }
    }
  }
  return text.substring(start, end).trim();
}

/// يختار من [ranked] (مرتبة bm25) ما يُرسل، ويقص الطويل حول أول تطابق.
/// يختار من [ranked] (بعد [rerankCandidates]) ما يُرسل، ويقص الطويل حول أول
/// تطابق. الفقرة التمهيدية تُرسل ومعها الفقرة التالية **بمعرّفها هي** فقرةً
/// مستقلة، فيبقى التحقق من كل اقتباس مقابل الفقرة صاحبة المعرّف (D28).
List<AskPassage> selectPassages(List<LocalParagraph> ranked, AskQuery query) {
  final highlight = query.highlightQuery;
  final out = <AskPassage>[];
  final ids = <String>{};
  var remaining = maxPassagesTotalChars;

  String? fit(LocalParagraph p, {required bool aroundMatch}) {
    final cap = remaining < maxPassageChars ? remaining : maxPassageChars;
    if (cap < minPassageChars) return null;
    final text = _clean(p.text);
    if (text.length <= cap) return text.trim();
    final matches = aroundMatch
        ? findMatches(text, highlight)
        : const <MatchSpan>[];
    return excerptAround(text, matches.isEmpty ? 0 : matches.first.start, cap);
  }

  for (final p in ranked) {
    if (out.length >= maxPassages) break;
    if (ids.contains(p.id)) continue;
    final next = isIntroParagraph(p.text) ? p.next : null;
    // تمهيد بلا مكان لما يليه لا فائدة منه وحده.
    if (next != null &&
        !ids.contains(next.id) &&
        out.length + 2 > maxPassages) {
      continue;
    }
    final sent = fit(p, aroundMatch: true);
    if (sent == null) break;
    if (sent.isEmpty) continue;
    ids.add(p.id);
    out.add(AskPassage(paragraph: p, sentText: sent));
    remaining -= sent.length;
    if (next != null && ids.add(next.id)) {
      // القول يبدأ من أول الفقرة التالية.
      final more = fit(next, aroundMatch: false);
      if (more != null && more.isNotEmpty) {
        out.add(AskPassage(paragraph: next, sentText: more));
        remaining -= more.length;
      }
    }
  }
  return out;
}
