/// تقسيم نص الفقرة إلى مقاطع نطق (ARCHITECTURE §10). Dart صافٍ.
///
/// - النثر: الفقرة مقطع واحد، والطويلة تُقسم على حدود الجمل إلى مقاطع
///   لا تتجاوز [maxSpeechChunk] حرفاً (حد أندرويد للنطق نحو 4,000).
/// - الشعر (الأبيات بـ `\n` والشطران بـ `\t`): كل شطر مقطع، بوقفة قصيرة بعد
///   الشطر الأول ووقفة أطول بعد البيت.
/// - النص المنطوق هو الأصل بالتشكيل (يحسّن النطق).
library;

/// أقصى طول لمقطع نطق واحد.
const maxSpeechChunk = 3500;

/// الوقفة بين شطري البيت، وبعد البيت، وبعد الفقرة الشعرية.
const hemistichPause = Duration(milliseconds: 400);
const versePause = Duration(milliseconds: 800);

class SpeechChunk {
  const SpeechChunk(this.text, {this.pauseAfter = Duration.zero});

  final String text;

  /// صمت بعد نطق المقطع.
  final Duration pauseAfter;

  @override
  bool operator ==(Object other) =>
      other is SpeechChunk &&
      other.text == text &&
      other.pauseAfter == pauseAfter;

  @override
  int get hashCode => Object.hash(text, pauseAfter);

  @override
  String toString() => 'SpeechChunk($text, $pauseAfter)';
}

/// مقاطع نطق فقرة. [kind] `prose` أو `verse`. فقرة فارغة ← لا مقاطع.
List<SpeechChunk> speechChunks(
  String text,
  String kind, {
  int maxLength = maxSpeechChunk,
}) {
  if (kind == 'verse') return _verseChunks(text, maxLength);
  final clean = _collapse(text);
  if (clean.isEmpty) return const [];
  return [
    for (final part in splitLongText(clean, maxLength)) SpeechChunk(part),
  ];
}

List<SpeechChunk> _verseChunks(String text, int maxLength) {
  final out = <SpeechChunk>[];
  final lines = text
      .split('\n')
      .map((l) => l.split('\t').map(_collapse).where((h) => h.isNotEmpty))
      .where((halves) => halves.isNotEmpty)
      .map((halves) => halves.toList())
      .toList();
  for (final halves in lines) {
    for (var h = 0; h < halves.length; h++) {
      final parts = splitLongText(halves[h], maxLength);
      for (var i = 0; i < parts.length; i++) {
        final lastOfHalf = i == parts.length - 1;
        final lastOfLine = h == halves.length - 1;
        out.add(
          SpeechChunk(
            parts[i],
            pauseAfter: !lastOfHalf
                ? Duration.zero
                : lastOfLine
                ? versePause
                : hemistichPause,
          ),
        );
      }
    }
  }
  return out;
}

String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// علامات نهاية الجملة (عربية ولاتينية)، ثم الفواصل كحل ثانٍ.
final _sentenceEnd = RegExp(r'[.!?؟۔…:؛]+\s+');
final _clauseEnd = RegExp(r'[،,]\s+');

/// يقسم نصاً مطوَّلاً إلى أجزاء ≤ [maxLength]: على حدود الجمل أولاً، ثم
/// الفواصل، ثم المسافات، ثم قطعاً صلباً إن لم يوجد فاصل.
List<String> splitLongText(String text, int maxLength) {
  final t = text.trim();
  if (t.isEmpty) return const [];
  if (t.length <= maxLength) return [t];
  final out = <String>[];
  var rest = t;
  while (rest.length > maxLength) {
    final cut =
        _lastBoundary(rest, maxLength, _sentenceEnd) ??
        _lastBoundary(rest, maxLength, _clauseEnd) ??
        _lastSpace(rest, maxLength) ??
        maxLength;
    final head = rest.substring(0, cut).trim();
    if (head.isNotEmpty) out.add(head);
    rest = rest.substring(cut).trim();
  }
  if (rest.isNotEmpty) out.add(rest);
  return out;
}

/// نهاية آخر مطابقة لـ [pattern] تقع ضمن أول [maxLength] حرفاً.
int? _lastBoundary(String s, int maxLength, RegExp pattern) {
  int? best;
  for (final m in pattern.allMatches(s)) {
    if (m.end > maxLength) break;
    best = m.end;
  }
  return best == null || best == 0 ? null : best;
}

int? _lastSpace(String s, int maxLength) {
  final i = s.lastIndexOf(' ', maxLength);
  return i <= 0 ? null : i + 1;
}
