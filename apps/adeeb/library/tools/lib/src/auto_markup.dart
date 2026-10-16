/// وسوم غير mARkdown شائعة في نسخ OpenITI (JK خاصة)، يحوّلها الوضع الآلي قبل القراءة بقواعد
/// مسمّاة معدودة، بعد إحصاء الوسم المجهول في تقرير الدفعة (أكثرها أولاً).
///
/// **الفاصل `|`** (JK: بين مداخل المعجم والتراجم والفصول): فقرة جديدة، ويُحذف رقم مجرد بعده
/// (`| 5800` رقم الترجمة في الطبعة).
///
/// **الأبيات** بصيغ غير `%~%`، تُحوَّل إلى صيغة
/// البيت المعتادة `# صدر %~% عجز` فيبنيها القارئ فقرة شعر (`kind: verse`، شطران بينهما Tab).
///
/// يعمل في الوضع الآلي فقط (الوصفات اليدوية لا تتغير). الصيغتان:
/// 1. **JK:** `# % صدر % عجز % 12` (أو `% %` فاصلاً، والإغلاق اختياري): الرقم في آخره رقم البيت
///    في الديوان فيُحذف؛ نثر بعد البيت (`% % وإن كانت …`) فقرة جديدة. السطر الملحق `~~` الذي فيه `%`
///    بعد بيت لم يُغلق تتمة له؛ و`~~% 12` أو `~~PageV01P001 12` بعد بيت يُحذف رقمه وتبقى علامته.
/// 2. **بين قوسين:** `( صدر % عجز )` داخل سطر أو وحده، وقد يسبقه رقم (`# 3 ( … )`، `# 97 - ( … )`):
///    النص قبله يبقى في سطره، والبيت فقرة، وما بعده فقرة جديدة.
///
/// السطر الذي فيه `%~%` لا يُمسّ. كل تحويل يُعدّ في [RemovalStats].
library;

import 'wikitext.dart' show RemovalStats;

final _delim = RegExp(r'\s*%(?:\s*%)*\s*');
final _markers = RegExp(r'PageV\d+P\d+|(?<![A-Za-z])ms\d+(?![A-Za-z0-9])');
final _digitsOnly = RegExp(r'^[\s0-9٠-٩]*$');
final _hasNumber = RegExp(r'[0-9٠-٩]');
final _arabic = RegExp('[ء-ي]');
final _parenVerse = RegExp(r'\(\s*([^()%]*?)\s*%\s*([^()%]*?)\s*\)');
final _leadNumber = RegExp(r'^\s*[0-9٠-٩]+\s*-?\s*$');

String _markersOf(String s) => _markers.allMatches(s).map((m) => m[0]).join(' ');

/// [s] بلا العلامات أرقامٌ فقط (رقم بيت) أو فارغ.
bool _numberOnly(String s) => _digitsOnly.hasMatch(s.replaceAll(_markers, ' '));

const statJkVerse = 'بيت بصيغة JK «% صدر % عجز %» (حُوّل إلى بيت)';
const statJkNumber = 'رقم بيت في الديوان (JK) (حُذف)';
const statJkJoined = 'سطر ملحق ~~ أكمل بيت JK (وُصل به)';
const statParenVerse = 'بيت بين قوسين «( صدر % عجز )» (حُوّل إلى بيت)';
const statTail = 'نثر بعد بيت في السطر نفسه (فقرة جديدة)';

int _delimCount(String s) => _delim.allMatches(s).length;

const statPipe = 'فاصل «|» (JK) ← فقرة جديدة';
const statPipeNumber = 'رقم بعد الفاصل «|» (رقم الطبعة) (حُذف)';
final _pipeNumber = RegExp(r'^\s*[0-9٠-٩]+(?:\s*-)?(?=\s|$)');

/// يحوّل أسطر المتن (بعد الترويسة) ويعيد أسطراً جديدة.
List<String> normalizeAutoMarkup(List<String> lines, RemovalStats stats) =>
    _normalizeVerses(_splitPipes(lines, stats), stats);

List<String> _splitPipes(List<String> lines, RemovalStats stats) {
  final out = <String>[];
  for (final line in lines) {
    if (!line.contains('|') || !(line.startsWith('# ') || line.startsWith('~~'))) {
      out.add(line);
      continue;
    }
    final parts = line.substring(2).split('|');
    stats.add(statPipe, parts.length - 1);
    for (var j = 0; j < parts.length; j++) {
      var t = parts[j];
      if (j > 0 && _pipeNumber.hasMatch(t)) {
        stats.add(statPipeNumber);
        t = t.replaceFirst(_pipeNumber, '');
      }
      if (t.trim().isEmpty) continue;
      // القطعة الأولى تبقى بوسم سطرها؛ ما بعد «|» فقرة جديدة.
      out.add('${j == 0 ? line.substring(0, 2) : '# '}${t.trim()}');
    }
  }
  return out;
}

List<String> _normalizeVerses(List<String> lines, RemovalStats stats) {
  final out = <String>[];
  var afterJk = false;
  for (var k = 0; k < lines.length; k++) {
    final line = lines[k];
    if (line.contains('%~%') || !(line.contains('%') || afterJk)) {
      if (line.trim().isNotEmpty) afterJk = false;
      out.add(line);
      continue;
    }
    if (RegExp(r'^#\s*%').hasMatch(line)) {
      var content = line.substring(1);
      // بيت لم يُغلق (أقل من ثلاثة فواصل) يكمله سطر ~~ فيه «%».
      while (_delimCount(content) < 3 && k + 1 < lines.length) {
        final next = lines[k + 1];
        if (!next.startsWith('~~') || !next.contains('%') || next.contains('%~%')) break;
        content = '$content ${next.substring(2)}';
        stats.add(statJkJoined);
        k++;
      }
      out.addAll(_jkLine(content, stats));
      afterJk = true;
      continue;
    }
    if (afterJk && line.startsWith('~~')) {
      final rest = line.substring(2).replaceFirst(RegExp(r'^\s*%(?:\s*%)*'), '');
      if (_numberOnly(rest)) {
        if (_hasNumber.hasMatch(rest.replaceAll(_markers, ''))) stats.add(statJkNumber);
        final m = _markersOf(rest);
        if (m.isNotEmpty) out.add('~~$m');
        continue;
      }
      if (rest != line.substring(2)) {
        stats.add(statTail);
        out.addAll(_parenLine('~~$rest', stats));
        afterJk = false;
        continue;
      }
    }
    if (line.trim().isNotEmpty) afterJk = false;
    out.addAll(_parenLine(line, stats));
  }
  return out;
}

/// سطر JK بلا «#» في أوله: `% صدر % عجز % ذيل`.
List<String> _jkLine(String content, RemovalStats stats) {
  final segs = content.split(_delim);
  // segs[0] فارغ (السطر يبدأ بـ«%»).
  var h1 = segs.length > 1 ? segs[1].trim() : '';
  var h2 = segs.length > 2 ? segs[2].trim() : '';
  var tail = segs.length > 3 ? segs.sublist(3).join(' ').trim() : '';
  if (h2.isNotEmpty && _numberOnly(h2) && tail.isEmpty) {
    // `% شطر % 12`: بيت بشطر واحد ورقمه.
    tail = h2;
    h2 = '';
  }
  final res = <String>[];
  var verseMarks = '';
  if (tail.isNotEmpty && _numberOnly(tail)) {
    if (_hasNumber.hasMatch(tail.replaceAll(_markers, ''))) stats.add(statJkNumber);
    verseMarks = _markersOf(tail);
    tail = '';
  }
  if (_arabic.hasMatch(h1) || _arabic.hasMatch(h2)) {
    stats.add(statJkVerse);
    res.add('# $h1 %~% $h2${verseMarks.isEmpty ? '' : ' $verseMarks'}'.trimRight());
  } else {
    final m = [_markersOf(h1), _markersOf(h2), verseMarks].where((x) => x.isNotEmpty).join(' ');
    if (m.isNotEmpty) res.add('~~$m');
  }
  if (tail.isNotEmpty) {
    stats.add(statTail);
    res.addAll(_parenLine('# $tail', stats));
  }
  return res;
}

/// يفصل كل `( صدر % عجز )` في السطر بيتاً مستقلاً.
List<String> _parenLine(String line, RemovalStats stats) {
  final m = _parenVerse.firstMatch(line);
  if (m == null || !(_arabic.hasMatch(m[1]!) || _arabic.hasMatch(m[2]!))) return [line];
  final res = <String>[];
  final prefix = line.startsWith('~~') ? '~~' : '# ';
  var before = line.substring(line.startsWith('~~') ? 2 : (line.startsWith('#') ? 1 : 0), m.start);
  if (_leadNumber.hasMatch(before) && _hasNumber.hasMatch(before)) {
    stats.add(statJkNumber);
    before = '';
  }
  if (before.trim().isNotEmpty) res.add('$prefix${before.trim()}');
  stats.add(statParenVerse);
  res.add('# ${m[1]!.trim()} %~% ${m[2]!.trim()}'.trimRight());
  final after = line.substring(m.end).trim();
  if (after.isNotEmpty) {
    if (_numberOnly(after)) {
      final mk = _markersOf(after);
      if (mk.isNotEmpty) res.add('~~$mk');
      if (_hasNumber.hasMatch(after.replaceAll(_markers, ''))) stats.add(statJkNumber);
    } else {
      stats.add(statTail);
      res.addAll(_parenLine('# $after', stats));
    }
  }
  return res;
}
