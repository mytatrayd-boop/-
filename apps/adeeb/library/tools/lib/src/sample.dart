/// عيّنة عشوائية (ببذرة ثابتة) من فقرات كتاب لمراجعة المالك.
library;

import 'dart:math';

import 'catalog.dart';
import 'validator.dart';

/// العدد الافتراضي للعيّنة (SPEC الميزة 1: فحص 20 فقرة عشوائية).
const defaultSampleCount = 20;

String buildSampleMarkdown(
  Map<String, Object?> book, {
  int count = defaultSampleCount,
  required int seed,
  ValidationExceptions exceptions = const {},
}) {
  // التحذيرات (مثل «(١٥)») تُعرض كلها للمراجع البشري، مع أو بلا اختيار عشوائي.
  final warnings = validateBook(book, '', exceptions: exceptions).where((i) => i.warning).toList();
  final warnedIds = {for (final w in warnings) w.paragraphId};
  final rows = <({String id, String chapter, String text, bool verse})>[];
  for (final c in (book['chapters']! as List).cast<Map<String, Object?>>()) {
    for (final p in (c['paragraphs']! as List).cast<Map<String, Object?>>()) {
      rows.add((
        id: p['id']! as String,
        chapter: c['title']! as String,
        text: p['text']! as String,
        verse: p['kind'] == 'verse',
      ));
    }
  }
  final idx = List.generate(rows.length, (i) => i)..shuffle(Random(seed));
  final picked = idx.take(count).toList()..sort();
  final title = (book['title']! as Map)['ar'];
  final source = book['source']! as Map;
  final b = StringBuffer()
    ..writeln('# عيّنة مراجعة — $title (الإصدار ${book['version']})')
    ..writeln()
    ..writeln('المصدر: ${source['url']} (جُلب ${source['retrieved']}). '
        'عدد الفقرات الكلي: ${paragraphsOf(book).length}. '
        'العيّنة: ${picked.length} فقرات عشوائية (بذرة $seed، تُعاد بالأمر نفسه).')
    ..writeln()
    ..writeln('للمراجعة: هل النص مطابق للمصدر؟ هل فيه حاشية أو تعليق محقق أو رقم حاشية؟ هل التشكيل كما في المصدر؟')
    ..writeln();
  var n = 1;
  for (final i in picked) {
    final r = rows[i];
    b
      ..writeln('## $n. `${r.id}` — ${r.chapter}${r.verse ? ' (شعر)' : ''}'
          '${warnedIds.contains(r.id) ? ' — فيها تحذير' : ''}')
      ..writeln();
    for (final line in r.text.split('\n')) {
      b.writeln('> ${line.replaceAll('\t', ' ... ')}');
      b.writeln('>');
    }
    b.writeln();
    n++;
  }
  b
    ..writeln('## تحذيرات للمراجعة (${warnings.length})')
    ..writeln();
  if (warnings.isEmpty) {
    b.writeln('لا توجد.');
  } else {
    b
      ..writeln('أرقام بين قوسين قد تكون حاشية متسربة أو من نص المؤلف. إن كانت من النص فأضف المعرّف '
          'إلى validation_exceptions في الوصفة؛ وإلا فاحذفها من المصدر عبر قواعد التحويل.')
      ..writeln();
    for (final w in warnings) {
      b.writeln('- `${w.paragraphId}` [${w.code}] ${w.detail}');
    }
  }
  return b.toString();
}
