import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/table_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';

void main() {
  const validator = TableValidator();

  List<String> errorsOf(Tables t, {bool release = false}) =>
      validator.validate(t, release: release).errors;

  Map<String, Object?> tableA(Map<String, Object?> tables) =>
      tables['a']! as Map<String, Object?>;

  test('جداول سليمة ومعتمدة تمر في التطوير والإطلاق', () {
    final t = fixtureTables();
    expect(errorsOf(t), isEmpty);
    expect(errorsOf(t, release: true), isEmpty);
    expect(t.hasUnapproved, isFalse);
  });

  test('سجل مسودة: تحذير في التطوير وفشل في الإطلاق', () {
    final t = fixtureTables(
      edit: (tables, _, _) {
        (tableA(tables)['durur']! as List)[0] = dar(
          '01-05',
          1,
          'أ',
          's1',
          approval: draft,
        );
      },
    );
    final dev = validator.validate(t);
    expect(dev.isValid, isTrue);
    expect(dev.warnings, hasLength(1));
    expect(errorsOf(t, release: true), hasLength(1));
    expect(t.hasUnapproved, isTrue);
  });

  for (final (label, approval) in [
    (
      'بلا مراجع',
      {'status': 'approved', 'reviewer': null, 'date': '2026-10-02'},
    ),
    (
      'بمراجع فارغ',
      {'status': 'approved', 'reviewer': ' ', 'date': '2026-10-02'},
    ),
    ('بلا تاريخ', {'status': 'approved', 'reviewer': 'test', 'date': null}),
    ('بتاريخ فارغ', {'status': 'approved', 'reviewer': 'test', 'date': ''}),
  ]) {
    test('سجل approved $label: يمر في التطوير ويفشل في الإطلاق', () {
      final t = fixtureTables(
        edit: (tables, _, _) {
          (tableA(tables)['durur']! as List)[0] = dar(
            '01-05',
            1,
            'أ',
            's1',
            approval: approval,
          );
        },
      );
      expect(errorsOf(t), isEmpty);
      final errors = errorsOf(t, release: true);
      expect(errors, hasLength(1));
      expect(errors.single, contains('بلا اسم المراجع أو تاريخ الاعتماد'));
    });
  }

  test('dataVersion تبدأ بـ sample: يمر في التطوير ويفشل في الإطلاق', () {
    final t = fixtureTables(dataVersion: 'sample-1');
    expect(errorsOf(t), isEmpty);
    final errors = errorsOf(t, release: true);
    expect(errors, hasLength(1));
    expect(errors.single, contains('sample-1'));
  });

  test('بدايات غير مرتبة أو مكررة', () {
    final t = fixtureTables(
      edit: (tables, _, _) {
        (tableA(tables)['durur']! as List)[1] = dar('01-05', 2, 'ب', 's1');
      },
    );
    expect(errorsOf(t).join(), contains('غير مرتبة أو مكررة'));
  });

  test('تداخل مواسم الجو', () {
    final t = fixtureTables(
      edit: (tables, _, _) {
        (tableA(tables)['weatherSeasons']! as List).add(
          wseason('w2', '01-01', '01-02'),
        );
      },
    );
    expect(errorsOf(t).join(), contains('تداخل'));
  });

  test('عنصر غير موجود أو من نوع خاطئ', () {
    final t = fixtureTables(
      edit: (tables, _, _) {
        tableA(tables)['stars'] = [layer('s1', '05-01')];
        (tableA(tables)['weatherSeasons']! as List).add(
          wseason('missing', '06-01', '06-02'),
        );
      },
    );
    final errors = errorsOf(t).join('\n');
    expect(errors, contains('نوعه majorSeason'));
    expect(errors, contains('"missing" غير موجود'));
  });

  test('seasonId في الدَّرّ يخالف الموسم الكبير يوم بدايته', () {
    final t = fixtureTables(
      edit: (tables, _, _) {
        (tableA(tables)['durur']! as List)[3] = dar('07-01', 1, 'هـ', 's1');
      },
    );
    expect(errorsOf(t).join(), contains('يخالف'));
  });

  test('تعريف أكثر من سطرين', () {
    final t = fixtureTables(
      edit: (_, _, items) {
        items[0] = item('s1', 'majorSeason', definition: 'أ\nب\nج');
      },
    );
    expect(errorsOf(t).join(), contains('3 أسطر'));
  });

  test('عدد المناطق ليس 4، وجدول منطقة مفقود', () {
    final t = fixtureTables(
      edit: (tables, regions, _) {
        regions.removeLast();
        tables.remove('c');
      },
    );
    final errors = errorsOf(t).join('\n');
    expect(errors, contains('عدد المناطق 3'));
    expect(errors, contains('regions/c.json: جدول المنطقة مفقود'));
    expect(errors, contains('regions/d.json: منطقة غير موجودة'));
  });

  group('أخطاء التحليل', () {
    test('29 فبراير مرفوض في الجداول', () {
      expect(
        () => fixtureTables(
          edit: (tables, _, _) {
            (tableA(tables)['durur']! as List)[1] = dar('02-29', 2, 'ب', 's1');
          },
        ),
        throwsFormatException,
      );
    });

    test('رمز جو غير معروف', () {
      expect(
        () => fixtureTables(
          edit: (_, _, items) {
            (items[0]! as Map<String, Object?>)['weather'] = ['snow'];
          },
        ),
        throwsFormatException,
      );
    });

    test('قاعدة 29 فبراير غير معروفة', () {
      expect(
        () => fixtureTables(
          edit: (_, regions, _) {
            (regions[0]! as Map<String, Object?>)['leapDayRule'] = 'skip';
          },
        ),
        throwsFormatException,
      );
    });

    test('سجل بلا مصدر أو بلا اعتماد', () {
      expect(
        () => fixtureTables(
          edit: (tables, _, _) {
            ((tableA(tables)['stars']! as List)[0] as Map).remove('source');
          },
        ),
        throwsFormatException,
      );
      expect(
        () => fixtureTables(
          edit: (tables, _, _) {
            ((tableA(tables)['stars']! as List)[0] as Map).remove('approval');
          },
        ),
        throwsFormatException,
      );
    });

    test('regionId لا يطابق اسم الملف', () {
      expect(
        () => fixtureTables(
          edit: (tables, _, _) {
            tableA(tables)['regionId'] = 'b';
          },
        ),
        throwsFormatException,
      );
    });
  });
}
