/// عيّنة عشوائية (ببذرة ثابتة) من فقرات كتاب لمراجعة المالك.
library;

import 'dart:math';

import 'catalog.dart';

String buildSampleMarkdown(Map<String, Object?> book, {required int count, required int seed}) {
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
      ..writeln('## $n. `${r.id}` — ${r.chapter}${r.verse ? ' (شعر)' : ''}')
      ..writeln();
    for (final line in r.text.split('\n')) {
      b.writeln('> ${line.replaceAll('\t', ' ... ')}');
      b.writeln('>');
    }
    b.writeln();
    n++;
  }
  return b.toString();
}
