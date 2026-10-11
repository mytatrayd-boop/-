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

const _verseMark = '';
const _verseBreak = '';
const _hemiSep = '';

const _strippedTags = {
  'center', 'div', 'span', 'p', 'big', 'small', 'b', 'i', 'u', 's', 'font',
  'blockquote', 'sub', 'strong', 'em', 'abbr', 'nowiki', 'noinclude',
  'onlyinclude', 'tt', 'cite', 'dfn', 'mark', 'ins', 'del', 'q',
};

const _droppedLinkPrefixes = {
  'category', 'تصنيف', 'file', 'ملف', 'image', 'صورة', 'media', 'وسائط',
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
    s = s.replaceAll(' ', ' ');
    return s;
  }

  // ---------- القوالب ----------

  String _expandTemplates(String s, RemovalStats stats) {
    final unknown = <String>{};
    final out = _expandTemplatesIn(s, stats, unknown);
    if (unknown.isNotEmpty) {
      final names = unknown.toList()..sort();
      throw WikitextException(
        'قوالب غير معروفة (أضفها إلى templates في الوصفة: drop أو unwrap أو verse): '
        '${names.join('، ')}',
      );
    }
    return out;
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
    final args = parts.skip(1).toList();
    final positional = [
      for (final a in args)
        if (!RegExp(r'^\s*[^=\[\]{}|]+=').hasMatch(a)) a,
    ];
    if (rules.verse.map(normalizeTemplateName).contains(name)) {
      final hemis = [
        for (final a in positional.take(2))
          _expandTemplatesIn(a, stats, unknown).trim(),
      ].where((h) => h.isNotEmpty).toList();
      return '\n$_verseMark${hemis.join(_hemiSep)}\n';
    }
    if (rules.drop.map(normalizeTemplateName).contains(name)) {
      stats.add('قالب: $name');
      return '';
    }
    for (final e in rules.unwrap.entries) {
      if (normalizeTemplateName(e.key) == name) {
        final idx = e.value - 1;
        if (idx < 0 || idx >= positional.length) return '';
        return _expandTemplatesIn(positional[idx], stats, unknown);
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
    final colon = target.indexOf(':');
    if (colon > 0) {
      final prefix = target.substring(0, colon).trim().toLowerCase();
      if (_droppedLinkPrefixes.contains(prefix) ||
          RegExp(r'^[a-z]{2,3}(-[a-z]+)?$').hasMatch(prefix)) {
        stats.add('رابط ملف/تصنيف/لغة');
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
        final lines = m[1]!.split('\n');
        final b = StringBuffer('\n');
        for (var line in lines) {
          line = line.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '');
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
              .split(RegExp(r'\t| {3,}|\s+\.\.\.\s+|\s+…\s+'))
              .map((h) => h.trim())
              .where((h) => h.isNotEmpty);
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
    RegExp('[​-‏‪-‮⁦-⁩﻿­]'),
    '',
  );
  s = s.replaceAll(RegExp(r'[\x00-\x1F\x7F-]'), ' ');
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
      'mdash': '—', 'zwnj': '‌', 'zwj': '‍', 'lrm': '', 'rlm': '',
    };
    return named[e.toLowerCase()] ?? m[0]!;
  });
}
