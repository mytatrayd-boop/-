/// أدوات قراءة ملفات Dart لفحوص الامتثال (الميزة 10).
library;

/// سلسلة نصية في ملف Dart: قيمتها كما كُتبت (بلا علامات التنصيص) وموضعها.
typedef DartString = ({String value, int offset, int line});

/// مُحلّل لفظي بسيط لملفات Dart: يتخطى التعليقات ويجمع السلاسل النصية
/// (`'…'`، `"…"`، الثلاثية، و`r'…'`) مع ما داخل `${…}` كما هو.
List<DartString> dartStrings(String src) => _scan(src).strings;

/// الكود بلا تعليقات (السلاسل تبقى كما هي).
String stripComments(String src) {
  final buffer = StringBuffer();
  var from = 0;
  for (final (start, end) in _scan(src).comments) {
    buffer.write(src.substring(from, start));
    from = end;
  }
  buffer.write(src.substring(from));
  return buffer.toString();
}

/// الكود وحده: التعليقات والسلاسل النصية (مع ما داخلها) تُستبدل بمسافات،
/// فلا يُخلط اسم في نص أو تعليق بكود فعلي. المواضع والأسطر محفوظة.
String codeOnly(String src) {
  final scan = _scan(src);
  final chars = src.split('');
  for (final (start, end) in [...scan.comments, ...scan.stringRanges]) {
    for (var k = start; k < end; k++) {
      if (chars[k] != '\n') chars[k] = ' ';
    }
  }
  return chars.join();
}

({
  List<DartString> strings,
  List<(int, int)> comments,
  List<(int, int)> stringRanges,
})
_scan(String src) {
  final strings = <DartString>[];
  final comments = <(int, int)>[];
  final stringRanges = <(int, int)>[];
  final n = src.length;
  int lineAt(int offset) =>
      '\n'.allMatches(src.substring(0, offset)).length + 1;

  // يعيد الموضع بعد نهاية السلسلة التي تبدأ عند [start]؛ [record] للسلاسل
  // العليا فقط (لا المتداخلة داخل ${…}).
  int skipString(int start, {required bool record}) {
    var j = start;
    var raw = false;
    if (src[j] == 'r') {
      raw = true;
      j++;
    }
    final triple = src.startsWith("'''", j) || src.startsWith('"""', j);
    final quote = triple ? src.substring(j, j + 3) : src[j];
    j += quote.length;
    final bodyStart = j;
    while (j < n) {
      if (!raw && src[j] == r'\') {
        j += 2;
        continue;
      }
      if (!raw && src.startsWith(r'${', j)) {
        j += 2;
        var depth = 1;
        while (j < n && depth > 0) {
          final c = src[j];
          if (c == "'" || c == '"') {
            j = skipString(j, record: false);
            continue;
          }
          if (c == '{') depth++;
          if (c == '}') depth--;
          j++;
        }
        continue;
      }
      if (src.startsWith(quote, j)) {
        if (record) {
          strings.add((
            value: src.substring(bodyStart, j),
            offset: start,
            line: lineAt(start),
          ));
        }
        return j + quote.length;
      }
      j++;
    }
    return n;
  }

  var i = 0;
  while (i < n) {
    if (src.startsWith('//', i)) {
      final e = src.indexOf('\n', i);
      final end = e < 0 ? n : e;
      comments.add((i, end));
      i = end;
      continue;
    }
    if (src.startsWith('/*', i)) {
      final e = src.indexOf('*/', i);
      final end = e < 0 ? n : e + 2;
      comments.add((i, end));
      i = end;
      continue;
    }
    final c = src[i];
    final isRaw =
        c == 'r' &&
        i + 1 < n &&
        (src[i + 1] == "'" || src[i + 1] == '"') &&
        (i == 0 || !RegExp(r'[\w$]').hasMatch(src[i - 1]));
    if (c == "'" || c == '"' || isRaw) {
      final start = i;
      i = skipString(i, record: true);
      stringRanges.add((start, i));
      continue;
    }
    i++;
  }
  return (strings: strings, comments: comments, stringRanges: stringRanges);
}
