import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<Object?, Object?> para(Map<String, Object?> b, int i) =>
    (((b['chapters']! as List)[0] as Map)['paragraphs']! as List)[i] as Map;

List<String> codes(Map<String, Object?> b) => validateBook(b, 't').map((i) => i.code).toList();

void main() {
  test('stripDiacritics يحذف الحركات والتطويل والألف الخنجرية فقط', () {
    expect(stripDiacritics('قَالَ: ـهٰذا، ١٢'), 'قال: هذا، ١٢');
    expect(ttsMatchesText('فِقْرَةٌ أُولَى.', 'فقرة أولى.'), isTrue);
    expect(ttsMatchesText('فِقْرَةٌ أُولَى', 'فقرة أولى.'), isFalse);
  });

  group('المدقق: tts', () {
    test('tts مشكول يطابق الأصل مقبول، والشعر بـ \\t و\\n', () {
      final b = validBook();
      para(b, 0)['tts'] = 'فِقْرَةٌ أُولَى.';
      para(b, 1)['tts'] = 'صَدْرٌ\tعَجُزٌ\nصَدْرٌ\tعَجُزٌ';
      expect(validateBook(b, 't'), isEmpty);
    });

    test('tts بحروف أو ترقيم مختلف أو فارغ أو غير نصي يُرفض', () {
      for (final bad in <Object>['فِقْرَةٌ ثَانِيَةٌ.', 'فِقْرَةٌ أُولَى', ' ', 3]) {
        // نسخة JSON بأنواع ديناميكية ليُقبل tts غير نصي.
        final b = jsonDecode(jsonEncode(validBook())) as Map<String, Object?>;
        para(b, 0)['tts'] = bad;
        expect(codes(b), contains('tts'), reason: '$bad');
      }
    });

    test('tts ليس NFC (شدة قبل الفتحة) يُرفض', () {
      final b = validBook()
        ..['chapters'] = [
          {
            'id': 'kalila-b001',
            'title': 'باب',
            'level': 1,
            'paragraphs': [
              {'id': 'kalila-b001-p00001', 'text': 'إن', 'tts': 'إِنَّ'},
            ],
          },
        ];
      expect(codes(b), ['tts']);
      para(b, 0)['tts'] = 'إِنَّ'; // NFC: الفتحة ثم الشدة.
      expect(codes(b), isEmpty);
    });
  });

  group('applyTts', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('adeeb_tts_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void writeV1() {
      final f = File('${tmp.path}/${bookRelativePath('kalila', 1)}')..createSync(recursive: true);
      f.writeAsBytesSync(gzipDeterministic(encodeBookJson(validBook())));
      buildCatalog(tmp, date: '2026-10-16');
    }

    test('إصدار جديد بالمعرّفات نفسها، والفهرس يزيد، والمدقق ينجح؛ وتكراره لا يغيّر شيئاً', () {
      writeV1();
      final tts = {'kalila-b001-p00001': 'فِقْرَةٌ أُولَى.', 'kalila-b001-p00002': 'صدر\tعجز\nصدر\tعجز'};
      final r = applyTts(tmp, 'kalila', tts);
      expect((r.fromVersion, r.toVersion, r.withTts), (1, 2, 1));
      final v2 = decodeGzJson(r.file!.readAsBytesSync());
      expect(v2['version'], 2);
      final ps = paragraphsOf(v2).toList();
      expect(ps.map((p) => p['id']), ['kalila-b001-p00001', 'kalila-b001-p00002']);
      expect(ps[0]['text'], 'فقرة أولى.');
      expect(ps[0]['tts'], 'فِقْرَةٌ أُولَى.');
      // tts يساوي النص: لا يُكتب.
      expect(ps[1].containsKey('tts'), isFalse);

      final cat = buildCatalog(tmp, date: '2026-10-17');
      expect(cat, contains('"catalog_version": 2'));
      expect(cat, contains('kalila.v2.json.gz'));
      final report = validateLibrary(tmp, exceptions: const {});
      expect(report.errors, isEmpty);
      expect(report.books, 2);

      final again = applyTts(tmp, 'kalila', tts);
      expect((again.toVersion, again.file), (2, null));
    });

    test('tts لا يطابق النص: يرمي ولا يكتب ملفاً', () {
      writeV1();
      expect(() => applyTts(tmp, 'kalila', {'kalila-b001-p00001': 'فِقْرَةٌ'}), throwsStateError);
      expect(File('${tmp.path}/${bookRelativePath('kalila', 2)}').existsSync(), isFalse);
    });
  });
}
