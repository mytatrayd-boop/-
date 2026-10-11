/// تحويل نص الويكي (wikitext) إلى كتل نظيفة: عناوين وفقرات نثر وأبيات.
/// دالة صافية حتمية. أي بنية غير معروفة (قالب، وسم، جدول، <pages>) تُرفض
/// بخطأ صريح بدل حذفها بصمت، حتى لا يضيع نص أو تتسرب حاشية.
library;

import 'arabic_nfc.dart';
import 'recipe.dart';

sealed class Block {
  const Block();
}

class HeadingBlock extends Block {
  const HeadingBlock(this.level, this.text);

  /// 2 لـ `==` و3 لـ `===`، وهكذا.
  final int level;
  final String text;
}

class ProseBlock extends Block {
  const ProseBlock(this.text);
  final String text;
}

class VerseBlock extends Block {
  const VerseBlock(this.lines);

  /// كل بيت قائمة أشطر (واحد أو اثنان).
  final List<List<String>> lines;

  /// الأبيات بـ \n والشطران بـ \t (ARCHITECTURE §4.2).
  String get text => lines.map((l) => l.join('\t')).join('\n');
}

class WikitextException implements Exception {
  WikitextException(this.message);
  final String message;
  @override
  String toString() => 'WikitextException: $message';
}

/// إحصاءات ما حُذف، لتوثيقه في SOURCES.md.
class RemovalStats {
  final Map<String, int> counts = {};
  void add(String key, [int n = 1]) {
    if (n == 0) return;
    counts[key] = (counts[key] ?? 0) + n;
  }

  void merge(RemovalStats other) => other.counts.forEach(add);

  List<String> lines() {
    final keys = counts.keys.toList()..sort();
    return [for (final k in keys) '$k: ${counts[k]}'];
  }
}

const _verseMark = '\uE000';
const _verseBreak = '\uE001';
const _hemiSep = '\uE002';
const _verseEnd = '\uE003';
const _verseStart = '\uE004';

const _strippedTags = {
  'center', 'div', 'span', 'p', 'big', 'small', 'b', 'i', 'u', 's', 'font',
  'blockquote', 'sub', 'strong', 'em', 'abbr', 'nowiki', 'noinclude',
  'onlyinclude', 'tt', 'cite', 'dfn', 'mark', 'ins', 'del', 'q',
};

const _droppedLinkPrefixes = {
  'category', 'تصنيف', 'file', 'ملف', 'image', 'صورة', 'media', 'وسائط',
};

/// رموز لغات روابط اللغات (interlanguage) التي لا تظهر في الصفحة.
/// قائمة صريحة: البادئات الأخرى (w: وwikt: ...) يبقى نصها الظاهر.
const interlanguageCodes = {
  'ar', 'en', 'fr', 'de', 'es', 'it', 'pt', 'ru', 'fa', 'ur', 'tr', 'he',
  'ku', 'ckb', 'az', 'id', 'ms', 'zh', 'ja', 'ko', 'nl', 'pl', 'sv', 'la',
  'el', 'hi', 'bn', 'sq', 'bs', 'arz', 'ary', 'mul',
};

final _letter = RegExp(r'\p{L}', unicode: true);

class WikitextConverter {
  WikitextConverter(this.rules);
  final TemplateRules rules;

  List<Block> convert(String wikitext, RemovalStats stats) {
    var s = wikitext.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    s = _preprocess(s, stats);
    s = _expandTemplates(s, stats);
    s = _expandLinks(s, stats);
    s = _poems(s);
    s = _tags(s, stats);
    s = s.replaceAll(RegExp(r"'{2,5}"), '');
    s = decodeEntities(s);
    return _blocks(s, stats);
  }

  String _preprocess(String s, RemovalStats stats) {
    s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    if (s.contains('<!--')) {
      throw WikitextException('تعليق <!-- بلا إغلاق: قد يخفي نصاً أو يُظهر ما ليس نصاً.');
    }
    final hidden = RegExp(
      r'''<[a-zA-Z][^>]*\bstyle\s*=\s*["'][^"']*display\s*:\s*none''',
      caseSensitive: false,
    ).firstMatch(s);
    if (hidden != null) {
      throw WikitextException('عنصر مخفي (display:none) غير مدعوم: ${hidden[0]}');
    }
    s = s.replaceAll(
      RegExp(r'<includeonly>[\s\S]*?</includeonly>', caseSensitive: false),
      '',
    );
    if (RegExp(r'<pages\b', caseSensitive: false).hasMatch(s)) {
      throw WikitextException(
        'وسم <pages> (تضمين صفحات Page:) غير مدعوم بعد؛ يلزم جلب صفحات المصدر.',
      );
    }
    if (RegExp(r'^\s*\{\|', multiLine: true).hasMatch(s)) {
      throw WikitextException('جدول ويكي ({|) غير مدعوم.');
    }
    var n = 0;
    s = s.replaceAllMapped(
      RegExp(r'<ref\b[^>]*?/>|<ref\b[^>]*>[\s\S]*?</ref\s*>',
          caseSensitive: false),
      (_) {
        n++;
        return '';
      },
    );
    stats.add('ref (حاشية)', n);
    n = 0;
    s = s.replaceAllMapped(
      RegExp(
        r'<references\b[^>]*?/>|<references\b[^>]*>[\s\S]*?</references\s*>',
        caseSensitive: false,
      ),
      (_) {
        n++;
        return '';
      },
    );
    stats.add('references (قائمة حواشٍ)', n);
    n = 0;
    s = s.replaceAllMapped(
      RegExp(r'<sup\b[^>]*>[\s\S]*?</sup\s*>', caseSensitive: false),
      (_) {
        n++;
        return '';
      },
    );
    stats.add('sup (رقم حاشية مرفوع)', n);
    s = s.replaceAll(RegExp(r'<section\b[^>]*/>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'__[A-Z]+__'), '');
    s = s.replaceAll(RegExp(r'&nbsp;|&#160;|&#xA0;', caseSensitive: false), ' ');
    s = s.replaceAll('\u00A0', ' ');
    return s;
  }

  // ---------- القوالب ----------

  String _expandTemplates(String s, RemovalStats stats) {
    final unknown = <String>{};
    final out = _expandTemplatesIn(s, stats, unknown);
    // بيت القالب على سطر مستقل دون إضافة أسطر فارغة، حتى تتجاور الأبيات المتتالية.
    final cleaned = out
        .replaceAll(RegExp('\n?$_verseStart'), '\n')
        .replaceAll(RegExp('$_verseEnd\n?'), '\n');
    if (unknown.isNotEmpty) {
      final names = unknown.toList()..sort();
      throw WikitextException(
        'قوالب غير معروفة (أضفها إلى templates في الوصفة: drop أو unwrap أو verse): '
        '${names.join('، ')}',
      );
    }
    return cleaned;
  }

  String _expandTemplatesIn(String s, RemovalStats stats, Set<String> unknown) {
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      if (s.startsWith('{{', i)) {
        final end = _matchClose(s, i, '{{', '}}');
        if (end < 0) throw WikitextException('{{ بلا إغلاق عند الموضع $i');
        final inner = s.substring(i + 2, end);
        b.write(_template(inner, stats, unknown));
        i = end + 2;
      } else {
        b.write(s[i]);
        i++;
      }
    }
    return b.toString();
  }

  String _template(String inner, RemovalStats stats, Set<String> unknown) {
    final parts = splitTopLevel(inner, '|');
    final rawName = parts.first.trim();
    final name = normalizeTemplateName(rawName);
    // دوال المحلّل والكلمات السحرية (مثل #if: وDEFAULTSORT:) لا تحمل نص كتاب.
    if (name.startsWith('#') ||
        RegExp(r'^[A-Z]+:').hasMatch(rawName) ||
        name.startsWith('ترتيب:')) {
      stats.add('قالب: $name');
      return '';
    }
    final args = parseTemplateArgs(parts.skip(1).toList());
    if (rules.verse.map(normalizeTemplateName).contains(name)) {
      if (args.named.isNotEmpty) {
        throw WikitextException(
          'قالب بيت «$name» بوسيط مسمّى غير معروف: ${args.named.keys.join('، ')}',
        );
      }
      final keys = args.positional.keys.toList()..sort();
      if (keys.any((k) => k > 2)) {
        throw WikitextException('قالب بيت «$name» بأكثر من شطرين: ${parts.join('|')}');
      }
      final hemis = [
        for (final k in keys) _expandTemplatesIn(args.positional[k]!, stats, unknown).trim(),
      ].where((h) => h.isNotEmpty).toList();
      if (hemis.isEmpty) {
        throw WikitextException('قالب بيت «$name» فارغ.');
      }
      return '$_verseStart$_verseMark${hemis.join(_hemiSep)}$_verseEnd';
    }
    if (rules.drop.map(normalizeTemplateName).contains(name)) {
      stats.add('قالب: $name');
      return '';
    }
    for (final e in rules.unwrap.entries) {
      if (normalizeTemplateName(e.key) == name) {
        final v = args.positional[e.value];
        if (v == null) {
          throw WikitextException('قالب «$name» بلا الوسيط ${e.value} المطلوب إبقاؤه: ${parts.join('|')}');
        }
        return _expandTemplatesIn(v, stats, unknown);
      }
    }
    unknown.add(name);
    return '';
  }

  // ---------- الروابط ----------

  String _expandLinks(String s, RemovalStats stats) {
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      if (s.startsWith('[[', i)) {
        final end = _matchClose(s, i, '[[', ']]');
        if (end < 0) throw WikitextException('[[ بلا إغلاق عند الموضع $i');
        final inner = s.substring(i + 2, end);
        b.write(_link(inner, stats));
        i = end + 2;
      } else {
        b.write(s[i]);
        i++;
      }
    }
    var out = b.toString();
    out = out.replaceAllMapped(
      RegExp(r'\[(https?://[^\s\]]+)\s+([^\]]*)\]'),
      (m) => m[2]!,
    );
    out = out.replaceAll(RegExp(r'\[https?://[^\s\]]+\]'), '');
    return out;
  }

  String _link(String inner, RemovalStats stats) {
    final parts = splitTopLevel(inner, '|');
    var target = parts.first.trim();
    // [[:تصنيف:س|نص]] بنقطتين في أوله رابط ظاهر لا تصنيف.
    final shown = target.startsWith(':');
    if (shown) target = target.substring(1).trim();
    final colon = target.indexOf(':');
    if (colon > 0 && !shown) {
      final prefix = target.substring(0, colon).trim().toLowerCase();
      if (_droppedLinkPrefixes.contains(prefix)) {
        stats.add('رابط ملف/تصنيف');
        return '';
      }
      if (interlanguageCodes.contains(prefix) && parts.length == 1) {
        stats.add('رابط لغة');
        return '';
      }
    }
    if (parts.length > 1) return _expandLinks(parts.last, stats);
    if (target.startsWith('/')) target = target.substring(1);
    return target.split('/').last.split('#').first;
  }

  // ---------- الشعر والوسوم ----------

  String _poems(String s) {
    return s.replaceAllMapped(
      RegExp(r'<poem\b[^>]*>([\s\S]*?)</poem\s*>', caseSensitive: false),
      (m) {
        // <br> داخل القصيدة فاصل سطر (بيت جديد) كما يعرضه الويكي.
        final lines = m[1]!
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
            .split('\n');
        final b = StringBuffer('\n');
        for (var line in lines) {
          if (line.trim().isEmpty) {
            b.write('$_verseBreak\n');
            continue;
          }
          if (line.startsWith(_verseMark)) {
            b.write('$line\n');
            continue;
          }
          line = line.replaceFirst(RegExp(r'^[:\s]+'), '');
          final hemis = line
              .split(RegExp(r'\t| {3,}'))
              .map((h) => h.trim())
              .where((h) => h.isNotEmpty)
              .toList();
          // مثل قالب البيت: لا أكثر من شطرين في البيت.
          if (hemis.length > 2) {
            throw WikitextException('سطر في <poem> بأكثر من شطرين (${hemis.length}): $line');
          }
          b.write('$_verseMark${hemis.join(_hemiSep)}\n');
        }
        b.write('$_verseBreak\n');
        return b.toString();
      },
    );
  }

  String _tags(String s, RemovalStats stats) {
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n\n');
    final unknown = <String>{};
    s = s.replaceAllMapped(RegExp(r'</?([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>'), (m) {
      final tag = m[1]!.toLowerCase();
      if (_strippedTags.contains(tag)) return '';
      unknown.add(tag);
      return '';
    });
    if (unknown.isNotEmpty) {
      final t = unknown.toList()..sort();
      throw WikitextException('وسوم HTML غير معروفة: ${t.join(', ')}');
    }
    return s;
  }

  // ---------- الكتل ----------

  List<Block> _blocks(String s, RemovalStats stats) {
    final blocks = <Block>[];
    final prose = <String>[];
    final verse = <List<String>>[];

    void flushProse() {
      if (prose.isEmpty) return;
      final t = cleanText(prose.join(' '));
      prose.clear();
      if (t.isEmpty) return;
      if (!_letter.hasMatch(t)) {
        stats.add('فقرة بلا حروف (فاصل)');
        return;
      }
      blocks.add(ProseBlock(t));
    }

    void flushVerse() {
      if (verse.isEmpty) return;
      final lines = [
        for (final l in verse)
          [
            for (final h in l)
              if (cleanText(h).isNotEmpty) cleanText(h),
          ],
      ].where((l) => l.isNotEmpty && l.any(_letter.hasMatch)).toList();
      verse.clear();
      if (lines.isNotEmpty) blocks.add(VerseBlock(lines));
    }

    final heading = RegExp(r'^(={1,6})\s*(.*?)\s*\1\s*$');
    for (final rawLine in s.split('\n')) {
      final line = rawLine.trimRight();
      final h = heading.firstMatch(line);
      if (h != null) {
        flushProse();
        flushVerse();
        final level = h[1]!.length < 2 ? 2 : h[1]!.length;
        final t = cleanText(h[2]!);
        if (t.isNotEmpty) blocks.add(HeadingBlock(level, t));
        continue;
      }
      if (line.startsWith(_verseMark)) {
        flushProse();
        verse.add(line.substring(1).split(_hemiSep));
        continue;
      }
      if (line.contains(_verseBreak) || line.trim().isEmpty) {
        flushProse();
        flushVerse();
        continue;
      }
      if (RegExp(r'^-{4,}\s*$').hasMatch(line)) {
        flushProse();
        flushVerse();
        continue;
      }
      final list = RegExp(r'^[*#:;]+\s*').firstMatch(line);
      if (list != null) {
        flushProse();
        flushVerse();
        prose.add(line.substring(list.end));
        flushProse();
        continue;
      }
      flushVerse();
      prose.add(line);
    }
    flushProse();
    flushVerse();
    return blocks;
  }
}

/// تنظيف نص فقرة: حذف محارف التنسيق غير المرئية، ضغط المسافات، NFC.
/// لا يمسّ التشكيل ولا التطويل ولا الحروف.
String cleanText(String s) {
  s = s.replaceAll(
    RegExp('[\u200B\u200D-\u200F\u202A-\u202E\u2066-\u2069\uFEFF\u00AD]'),
    '',
  );
  s = s.replaceAll(RegExp(r'[\x00-\x1F\x7F\uE000-\uE004]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final bad = unsupportedMarks(s);
  if (bad.isNotEmpty) {
    throw WikitextException(
      'علامات دمج غير عربية غير مدعومة: '
      '${bad.map((c) => 'U+${c.toRadixString(16).toUpperCase()}').join(', ')}',
    );
  }
  return arabicNfc(s);
}

class TemplateArgs {
  TemplateArgs(this.positional, this.named);

  /// بالرقم (1، 2، ...): الموضعية بالترتيب، أو المسمّاة رقماً صراحة مثل 2=.
  final Map<int, String> positional;
  final Map<String, String> named;
}

/// وسائط القالب كما في ميدياويكي: `اسم=قيمة` مسمّى إن كان الاسم كلمة واحدة
/// بلا مسافات؛ الاسم الرقمي (1= 2=) موضعي صريح. «=» داخل نص فيه مسافات
/// قبلها (مثل شطر) لا يجعله مسمّى.
TemplateArgs parseTemplateArgs(List<String> args) {
  final positional = <int, String>{};
  final named = <String, String>{};
  var next = 1;
  final namedRe = RegExp(r'^\s*([^\s=\[\]{}|]+)\s*=([\s\S]*)$');
  for (final a in args) {
    final eq = _topLevelIndexOf(a, '=');
    final m = eq >= 0 ? namedRe.firstMatch(a) : null;
    if (m != null && a.indexOf('=') == eq) {
      final key = m[1]!;
      final n = int.tryParse(key);
      if (n != null && n > 0) {
        positional[n] = m[2]!;
      } else {
        named[key] = m[2]!;
      }
    } else {
      positional[next++] = a;
    }
  }
  return TemplateArgs(positional, named);
}

int _topLevelIndexOf(String s, String ch) {
  final parts = splitTopLevel(s, ch);
  return parts.length > 1 ? parts.first.length : -1;
}

String normalizeTemplateName(String name) {
  var n = name.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final p in ['قالب:', 'Template:', 'template:']) {
    if (n.startsWith(p)) n = n.substring(p.length).trim();
  }
  if (n.isEmpty) return n;
  return n[0].toUpperCase() + n.substring(1);
}

/// موضع بداية الإغلاق المطابق مع مراعاة التداخل، أو -1.
int _matchClose(String s, int start, String open, String close) {
  var depth = 0;
  var i = start;
  while (i < s.length) {
    if (s.startsWith(open, i)) {
      depth++;
      i += open.length;
    } else if (s.startsWith(close, i)) {
      depth--;
      if (depth == 0) return i;
      i += close.length;
    } else {
      i++;
    }
  }
  return -1;
}

/// تقسيم على الفاصل في المستوى الأعلى فقط (خارج {{ }} و[[ ]]).
List<String> splitTopLevel(String s, String sep) {
  final out = <String>[];
  var depthT = 0, depthL = 0, last = 0;
  var i = 0;
  while (i < s.length) {
    if (s.startsWith('{{', i)) {
      depthT++;
      i += 2;
    } else if (s.startsWith('}}', i)) {
      depthT--;
      i += 2;
    } else if (s.startsWith('[[', i)) {
      depthL++;
      i += 2;
    } else if (s.startsWith(']]', i)) {
      depthL--;
      i += 2;
    } else if (depthT == 0 && depthL == 0 && s.startsWith(sep, i)) {
      out.add(s.substring(last, i));
      i += sep.length;
      last = i;
    } else {
      i++;
    }
  }
  out.add(s.substring(last));
  return out;
}

String decodeEntities(String s) {
  return s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'),
      (m) {
    final e = m[1]!;
    if (e.startsWith('#x') || e.startsWith('#X')) {
      return String.fromCharCode(int.parse(e.substring(2), radix: 16));
    }
    if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
    const named = {
      'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'",
      'nbsp': ' ', 'laquo': '«', 'raquo': '»', 'hellip': '…', 'ndash': '–',
      'mdash': '—', 'zwnj': '\u200C', 'zwj': '\u200D', 'lrm': '', 'rlm': '',
    };
    return named[e.toLowerCase()] ?? m[0]!;
  });
}
