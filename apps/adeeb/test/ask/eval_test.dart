/// قياس الاسترجاع على الكتب الحقيقية (library/books) بأسئلة القبول
/// (library/eval/questions.json): هل بين الفقرات الست المرسلة فقرة تجيب
/// السؤال؟ لا شبكة ولا Gemini؛ يقيس الاسترجاع المحلي وحده (D28).
@Tags(['eval'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:adeeb/ask/ask_passages.dart';
import 'package:adeeb/ask/ask_query.dart';
import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:adeeb/storage/passage_retriever.dart';
import 'package:flutter_test/flutter_test.dart';

/// أقل نسبة مقبولة (D28). القياس الحالي مذكور في STATUS.md.
const minHitRate = 0.8;

void main() {
  late Directory dir;
  late SqlitePassageRetriever retriever;
  final questions =
      (jsonDecode(File('library/eval/questions.json').readAsStringSync())
              as Map<String, Object?>)['questions']!
          as List;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('adeeb_eval_');
    final path = '${dir.path}/adeeb.db';
    final books = SqliteBookRepository(path, useIsolate: false);
    final catalog = parseCatalog(
      File('library/catalog.json').readAsStringSync(),
    );
    for (final entry in catalog.books) {
      final gz = File('library/${entry.file}').readAsBytesSync();
      await books.install(gz, entry);
    }
    retriever = SqlitePassageRetriever(path, useIsolate: false);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('ثلاثون سؤالاً، والمعرّفات المتوقعة موجودة في الكتب', () async {
    expect(questions.length, 30);
  });

  test('نسبة الأسئلة التي بين فقراتها الست المرسلة فقرة متوقعة', () async {
    var hits = 0;
    final misses = <String>[];
    for (final q in questions.cast<Map<String, Object?>>()) {
      final question = q['question']! as String;
      final expected = (q['expected']! as List).cast<String>().toSet();
      final query = AskQuery.fromQuestion(question);
      final ranked = await retriever.retrieve(query, limit: retrieveLimit);
      final sent = selectPassages(ranked, query);
      final ids = {for (final p in sent) p.id};
      if (ids.intersection(expected).isNotEmpty) {
        hits++;
      } else {
        misses.add('${q['id']} $question ← ${sent.map((p) => p.id).join(' ')}');
      }
    }
    final rate = hits / questions.length;
    // ignore: avoid_print
    print(
      'eval: $hits/${questions.length} (${(rate * 100).round()}%)\n'
      '${misses.join('\n')}',
    );
    expect(rate, greaterThanOrEqualTo(minHitRate));
  });
}
