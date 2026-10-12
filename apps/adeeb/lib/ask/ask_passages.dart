/// اختيار الفقرات المرسلة إلى الخادم (ARCHITECTURE §7، §8.4): أفضل 6 فقرات
/// بترتيب bm25، كل فقرة ≤ 1,500 حرف والمجموع ≤ 8,000، والفقرة الطويلة تُقص
/// على حدود الكلمات حول أول تطابق. Dart صافٍ.
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

/// فقرة من القاعدة المحلية بنصها الكامل الأصلي (بالتشكيل).
class LocalParagraph {
  const LocalParagraph({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.text,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final String text;
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
List<AskPassage> selectPassages(List<LocalParagraph> ranked, AskQuery query) {
  final highlight = query.highlightQuery;
  final out = <AskPassage>[];
  final ids = <String>{};
  var remaining = maxPassagesTotalChars;
  for (final p in ranked) {
    if (out.length == maxPassages) break;
    if (!ids.add(p.id)) continue;
    final cap = remaining < maxPassageChars ? remaining : maxPassageChars;
    if (cap < minPassageChars) break;
    final text = _clean(p.text);
    final String sent;
    if (text.length <= cap) {
      sent = text.trim();
    } else {
      final matches = findMatches(text, highlight);
      sent = excerptAround(
        text,
        matches.isEmpty ? 0 : matches.first.start,
        cap,
      );
    }
    if (sent.isEmpty) continue;
    out.add(AskPassage(paragraph: p, sentText: sent));
    remaining -= sent.length;
  }
  return out;
}
