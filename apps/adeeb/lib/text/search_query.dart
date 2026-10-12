/// استعلام البحث المحلي (ARCHITECTURE §6): تحليله إلى كلمات وعبارات مطبَّعة،
/// وبناء تعبير FTS5، وإيجاد مواضع التطابق في النص الأصلي المشكول للتظليل،
/// والمقتطف. Dart صافٍ.
library;

import 'arabic_normalizer.dart';
import 'light_stemmer.dart';

/// كلمة (تطابق `norm` أو `stem`) أو عبارة بين علامتي تنصيص (تطابق `norm`
/// حرفياً بعد التطبيع).
class SearchTerm {
  const SearchTerm._(this.words, this.quoted);

  /// الكلمات مطبَّعة.
  final List<String> words;
  final bool quoted;

  /// جذع الكلمة المفردة غير المنصّصة (null للعبارة).
  String? get stem => quoted || words.length != 1 ? null : lightStem(words[0]);

  String _fts() {
    final phrase = words.join(' ');
    final s = stem;
    // المطبَّع حروف وأرقام ومسافات فقط، فلا يحوي علامة تنصيص.
    return s == null ? 'norm:"$phrase"' : '(norm:"$phrase" OR stem:"$s")';
  }
}

class SearchQuery {
  const SearchQuery._(this.raw, this.terms);

  /// يحلّل نص المستخدم: ما بين "…" أو «…» أو “…” عبارة، والباقي كلمات
  /// مربوطة بـ AND. علامة تنصيص بلا إغلاق تُعامل كمسافة.
  factory SearchQuery.parse(String raw) {
    final terms = <SearchTerm>[];
    void addWords(String text) {
      final norm = normalizeArabic(text);
      if (norm.isEmpty) return;
      for (final w in norm.split(' ')) {
        terms.add(SearchTerm._([w], false));
      }
    }

    const closing = {'"': '"', '«': '»', '“': '”'};
    var rest = 0;
    var i = 0;
    while (i < raw.length) {
      final close = closing[raw[i]];
      final end = close == null ? -1 : raw.indexOf(close, i + 1);
      if (end < 0) {
        i++;
        continue;
      }
      addWords(raw.substring(rest, i));
      final phrase = normalizeArabic(raw.substring(i + 1, end));
      if (phrase.isNotEmpty) {
        terms.add(SearchTerm._(phrase.split(' '), true));
      }
      i = end + 1;
      rest = i;
    }
    addWords(raw.substring(rest));
    return SearchQuery._(raw, List.unmodifiable(terms.take(maxTerms)));
  }

  /// حد لعدد الكلمات والعبارات حتى لا يثقل استعلام طويل جداً.
  static const maxTerms = 12;

  final String raw;
  final List<SearchTerm> terms;

  bool get isEmpty => terms.isEmpty;

  /// عدد الحروف المطبَّعة (بلا مسافات)؛ البحث يبدأ من حرفين (DESIGN §11.1).
  int get letterCount =>
      terms.fold(0, (n, t) => n + t.words.fold(0, (m, w) => m + w.length));

  bool get isSearchable => letterCount >= 2;

  /// تعبير MATCH لجدول `paragraphs_fts`: الكلمات والعبارات بـ AND.
  String toFtsMatch() => terms.map((t) => t._fts()).join(' AND ');
}

/// مدى في النص الأصلي بوحدات UTF-16 ([end] حصري).
class MatchSpan {
  const MatchSpan(this.start, this.end);
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is MatchSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MatchSpan($start, $end)';
}

/// مواضع كلمات [query] في [original] بتشكيلها، مرتبة وبلا تداخل. يطابق
/// منطق FTS5 نفسه: الكلمة تساوي الكلمة المطبَّعة أو جذعها يساوي جذعها،
/// والعبارة كلمات متتالية متساوية.
List<MatchSpan> findMatches(String original, SearchQuery query) {
  if (query.isEmpty || original.isEmpty) return const [];
  final n = normalizeArabicWithMap(original);
  if (n.text.isEmpty) return const [];
  final tokenStarts = <int>[];
  final tokenEnds = <int>[];
  final tokens = <String>[];
  var start = 0;
  for (var i = 0; i <= n.text.length; i++) {
    if (i == n.text.length || n.text.codeUnitAt(i) == 0x20) {
      if (i > start) {
        tokens.add(n.text.substring(start, i));
        tokenStarts.add(start);
        tokenEnds.add(i);
      }
      start = i + 1;
    }
  }
  final stems = List<String?>.filled(tokens.length, null);
  String stemAt(int t) => stems[t] ??= lightStem(tokens[t]);

  final spans = <MatchSpan>[];
  for (var t = 0; t < tokens.length; t++) {
    for (final term in query.terms) {
      final words = term.words;
      if (t + words.length > tokens.length) continue;
      final termStem = term.stem;
      final bool hit;
      if (termStem != null) {
        hit = tokens[t] == words[0] || stemAt(t) == termStem;
      } else {
        var all = true;
        for (var k = 0; k < words.length && all; k++) {
          all = tokens[t + k] == words[k];
        }
        hit = all;
      }
      if (hit) {
        final last = t + words.length - 1;
        spans.add(
          MatchSpan(n.starts[tokenStarts[t]], n.ends[tokenEnds[last] - 1]),
        );
      }
    }
  }
  if (spans.isEmpty) return const [];
  spans.sort((a, b) => a.start != b.start ? a.start - b.start : b.end - a.end);
  final merged = <MatchSpan>[spans.first];
  for (final s in spans.skip(1)) {
    final last = merged.last;
    if (s.start < last.end) {
      if (s.end > last.end) {
        merged[merged.length - 1] = MatchSpan(last.start, s.end);
      }
    } else {
      merged.add(s);
    }
  }
  return merged;
}

/// مقتطف من الفقرة حول أول تطابق، مع مواضع التظليل فيه.
class Snippet {
  const Snippet(this.text, this.spans);
  final String text;
  final List<MatchSpan> spans;
}

const ellipsis = '…';

/// يقتطع من [original] نحو [maxLength] محرفاً تبدأ قبل أول تطابق بنحو
/// [before] محرفاً، على حدود الكلمات، و«…» عند القطع. فواصل الأبيات والشطور
/// تصير مسافات.
Snippet buildSnippet(
  String original,
  List<MatchSpan> matches, {
  int before = 60,
  int maxLength = 240,
}) {
  final flat = original.replaceAll('\n', ' ').replaceAll('\t', ' ');
  final len = flat.length;
  var start = 0;
  if (matches.isNotEmpty && matches.first.start > before) {
    final first = matches.first.start;
    start = first - before;
    final space = flat.indexOf(' ', start);
    if (space >= 0 && space < first) start = space + 1;
  }
  var end = len;
  if (end - start > maxLength) {
    end = start + maxLength;
    final firstEnd = matches.isEmpty ? start : matches.first.end;
    if (end < firstEnd) end = firstEnd;
    final space = flat.lastIndexOf(' ', end);
    if (space > firstEnd && space > start) end = space;
  }
  final prefix = start > 0 ? ellipsis : '';
  final text =
      '$prefix${flat.substring(start, end)}${end < len ? ellipsis : ''}';
  final shift = prefix.length - start;
  final spans = [
    for (final m in matches)
      if (m.end > start && m.start < end)
        MatchSpan(
          (m.start < start ? start : m.start) + shift,
          (m.end > end ? end : m.end) + shift,
        ),
  ];
  return Snippet(text, spans);
}
