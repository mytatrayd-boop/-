/// التحقق في التطبيق من اقتباسات النموذج (ARCHITECTURE §7، D12، D24):
/// المعرّف من الفقرات المرسلة، و`normalize(quote)` ≥ 12 حرفاً وجزء متصل من
/// `normalize(نص الفقرة المحلي الكامل)` **على حدود الكلمات** كما في الخادم
/// (`worker/src/verify.ts`). الاقتباس المعروض يُؤخذ من النص المحلي الأصلي
/// بتشكيله عبر خريطة المواضع، لا من نص النموذج. Dart صافٍ.
library;

import '../text/arabic_normalizer.dart';
import '../text/search_query.dart';
import 'ask_passages.dart';

const minQuoteChars = 12;
const maxCitations = 3;

/// اقتباس النموذج كما ورد في الرد.
class RawCitation {
  const RawCitation({required this.paragraphId, required this.quote});
  final String paragraphId;
  final String quote;
}

/// اقتباس متحقَّق منه: [quote] مأخوذ من النص المحلي، و[span] موضعه فيه.
class VerifiedCitation {
  const VerifiedCitation({
    required this.paragraphId,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.quote,
  });

  final String paragraphId;
  final String bookId;
  final String bookTitle;
  final String chapterTitle;

  /// نص الاقتباس من الفقرة المحلية الأصلية (بالتشكيل).
  final String quote;

  Map<String, Object?> toJson() => {
    'paragraph_id': paragraphId,
    'book_id': bookId,
    'book_title': bookTitle,
    'chapter_title': chapterTitle,
    'quote': quote,
  };

  static VerifiedCitation? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['paragraph_id'];
    final book = json['book_id'];
    final bookTitle = json['book_title'];
    final chapter = json['chapter_title'];
    final quote = json['quote'];
    if (id is! String ||
        book is! String ||
        bookTitle is! String ||
        chapter is! String ||
        quote is! String) {
      return null;
    }
    return VerifiedCitation(
      paragraphId: id,
      bookId: book,
      bookTitle: bookTitle,
      chapterTitle: chapter,
      quote: quote,
    );
  }
}

/// موضع [quote] في [paragraphText] بعد التطبيع على حدود الكلمات، أو null.
MatchSpan? locateQuote(String quote, String paragraphText) {
  final q = normalizeArabic(quote);
  if (q.length < minQuoteChars) return null;
  final n = normalizeArabicWithMap(paragraphText);
  // المسافتان حول النصين تفرضان حدود الكلمات في الطرفين.
  final at = ' ${n.text} '.indexOf(' $q ');
  if (at < 0) return null;
  return MatchSpan(n.starts[at], n.ends[at + q.length - 1]);
}

/// يُبقي الاقتباسات الصحيحة فقط (حتى 3، بلا تكرار) مقابل النص المحلي الكامل
/// للفقرات المرسلة [sent].
List<VerifiedCitation> verifyCitations(
  List<RawCitation> citations,
  List<AskPassage> sent,
) {
  final byId = {for (final p in sent) p.id: p.paragraph};
  final seen = <String>{};
  final out = <VerifiedCitation>[];
  for (final c in citations) {
    final p = byId[c.paragraphId];
    if (p == null) continue;
    final span = locateQuote(c.quote, p.text);
    if (span == null) continue;
    if (!seen.add('${p.id}:${span.start}:${span.end}')) continue;
    out.add(
      VerifiedCitation(
        paragraphId: p.id,
        bookId: p.bookId,
        bookTitle: p.bookTitle,
        chapterTitle: p.chapterTitle,
        quote: p.text.substring(span.start, span.end),
      ),
    );
    if (out.length == maxCitations) break;
  }
  return out;
}
