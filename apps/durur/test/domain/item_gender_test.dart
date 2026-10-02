import 'dart:convert';
import 'dart:io';

import 'package:durur/src/domain/item.dart';
import 'package:durur/src/domain/json_utils.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// جنس النجم (DESIGN §13 «جنس النجم»، DECISIONS D30): حقل `gender` في
/// items.json، إلزامي للنجوم المحسوبة فلكياً، والافتراضي `m` لغيرها.
void main() {
  Map<String, Object?> star({
    String id = 'x',
    String dateMethod = 'table',
    Object? gender,
    bool withGender = false,
  }) => {
    'id': id,
    'kind': 'star',
    'name': {'ar': 'نجم'},
    'dateMethod': dateMethod,
    'gender': ?(withGender ? gender : null),
    'definition': {'ar': 'تعريف'},
    'proverb': {'ar': 'مثل'},
    'weather': ['hot'],
    'sources': [
      {'title': 'مصدر', 'author': null, 'year': null, 'page': null},
    ],
    'approval': {'status': 'draft', 'reviewer': null, 'date': null},
  };

  Matcher formatError(String part) => throwsA(
    isA<FormatException>().having((e) => e.message, 'message', contains(part)),
  );

  group('المحلل (Item.fromJson)', () {
    test('"m" و"f" تُقرآن', () {
      expect(
        Item.fromJson(star(withGender: true, gender: 'f'), 'items.json').gender,
        StarGender.feminine,
      );
      expect(
        Item.fromJson(
          star(dateMethod: 'heliacal', withGender: true, gender: 'm'),
          'items.json',
        ).gender,
        StarGender.masculine,
      );
    });

    test('غيابه في نجم من الجدول ← مذكر افتراضاً', () {
      expect(Item.fromJson(star(), 'items.json').gender, StarGender.masculine);
    });

    test('يرفض نجماً محسوباً فلكياً بلا gender (ولا null)', () {
      expect(
        () => Item.fromJson(
          star(id: 'thurayya', dateMethod: 'heliacal'),
          'items.json',
        ),
        formatError('"gender" إلزامي'),
      );
      expect(
        () => Item.fromJson(
          star(id: 'thurayya', dateMethod: 'heliacal', withGender: true),
          'items.json',
        ),
        formatError('items.json[thurayya]'),
      );
    });

    test('يرفض قيمة غير "m"/"f" أو نوعاً غير نصي', () {
      for (final bad in ['F', 'male', '']) {
        expect(
          () =>
              Item.fromJson(star(withGender: true, gender: bad), 'items.json'),
          formatError('جنس غير معروف'),
          reason: bad,
        );
      }
      expect(
        () => Item.fromJson(star(withGender: true, gender: 1), 'items.json'),
        throwsFormatException,
      );
    });
  });

  group('الجداول المضمّنة والمسودة', () {
    test(
      'assets: سهيل m والثريا f، وكل محسوب فلكياً فيه gender صريح',
      () async {
        final raw = asList(
          jsonDecode(await File(TablesLoader.itemsPath).readAsString()),
          'items.json',
        );
        final tables = await TablesLoader((path) => File(path).readAsString())
            .load();
        expect(tables.items['suhail']!.gender, StarGender.masculine);
        expect(tables.items['thurayya']!.gender, StarGender.feminine);
        for (final r in raw.cast<Map<String, dynamic>>()) {
          if (r['dateMethod'] == 'heliacal') {
            expect(r['gender'], isIn(['m', 'f']), reason: '${r['id']}');
          }
        }
      },
    );

    test(
      'research/drafts/items.json: gender صريح لسهيل (m) والثريا (f)',
      () async {
        // المسودة ليست قابلة للتحميل كاملة بعد (أمثال فارغة null)، فيُفحص
        // الحقل نفسه في السجلات المحسوبة فلكياً.
        final raw = asList(
          jsonDecode(await File('research/drafts/items.json').readAsString()),
          'drafts/items.json',
        ).cast<Map<String, dynamic>>();
        final genders = {
          for (final r in raw)
            if (r['dateMethod'] == 'heliacal') r['id']: r['gender'],
        };
        expect(genders, {'suhail': 'm', 'thurayya': 'f'});
      },
    );

    test(
      'validate_tables يرفض (عبر المحمّل) items.json بثريا بلا gender',
      () async {
        Future<String> read(String path) async {
          final text = await File(path).readAsString();
          if (path != TablesLoader.itemsPath) return text;
          final items = (jsonDecode(text) as List).cast<Map<String, dynamic>>();
          items.firstWhere((i) => i['id'] == 'thurayya').remove('gender');
          return jsonEncode(items);
        }

        await expectLater(
          TablesLoader(read).load(),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(contains('thurayya'), contains('"gender"')),
            ),
          ),
        );
      },
    );
  });
}
