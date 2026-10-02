import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/table_validator.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';
import '../helpers/app_harness.dart';
import 'engine_expectations.dart';

/// D24: استعارة الدرور (`dururBorrow`) في المحلل والمحرك والمدقق.
/// في الجداول الصغيرة: المنطقة c تستعير درور b (ج يبدأ 03-05)، ومواسمها
/// الكبيرة خاصة بها (01-10 و07-05) لتمييزها عن b.
Map<String, Object?> borrow(String from, {Object approval = approved}) => {
  'fromRegionId': from,
  'note': {'ar': 'سطر ثابت تجريبي'},
  'source': fixtureSource,
  'approval': approval,
};

Tables borrowingTables({
  void Function(Map<String, Object?> c, Map<String, Object?> all)? edit,
}) => fixtureTables(
  edit: (tables, regions, items) {
    final c = tables['c']! as Map<String, Object?>;
    c['durur'] = <Object?>[];
    c['dururBorrow'] = borrow('b');
    c['majorSeasons'] = [layer('s1', '01-10'), layer('s2', '07-05')];
    edit?.call(c, tables);
  },
);

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('المحلل', () {
    test('dururBorrow يُقرأ ويدخل في السجلات الخاضعة للاعتماد', () {
      final t = borrowingTables();
      final b = t.regionTables['c']!.dururBorrow!;
      expect(b.fromRegionId, 'b');
      expect(b.note.ar, 'سطر ثابت تجريبي');
      expect(t.regionTables['c']!.borrowsDurur, isTrue);
      expect(t.regionTables['a']!.borrowsDurur, isFalse);
      expect(t.allRecords, contains(same(b)));
    });

    test('note فارغ أو بلا مصدر أو بلا اعتماد ← خطأ تحليل', () {
      for (final mutate in <void Function(Map<String, Object?>)>[
        (b) => b['note'] = {'ar': ' '},
        (b) => b.remove('note'),
        (b) => b.remove('source'),
        (b) => b.remove('approval'),
        (b) => b.remove('fromRegionId'),
      ]) {
        expect(
          () => borrowingTables(
            edit: (c, _) => mutate(c['dururBorrow']! as Map<String, Object?>),
          ),
          throwsFormatException,
        );
      }
    });
  });

  group('المحرك', () {
    final t = borrowingTables();
    final c = CalendarEngine.fromTables(t, 'c');
    final b = CalendarEngine.fromTables(t, 'b');
    final a = CalendarEngine.fromTables(t, 'a');

    test('الدَّرّ من المُعيرة، وبقية الطبقات من المنطقة نفسها', () {
      final date = DateTime(2026, 3, 3);
      final info = c.resolve(date);
      expect(info.regionId, 'c');
      expect(info.dururRegionId, 'b');
      expect(info.borrowsDurur, isTrue);
      expect(info.dar.record, same(b.resolve(date).dar.record));
      expect(info.dar.record.regionId, 'b');
      // a يختلف عن b في هذا اليوم، فالنتيجة ليست من جدول آخر صدفة.
      expect(info.dar.name.ar, isNot(a.resolve(date).dar.name.ar));
      expect(info.majorSeason.start, DateTime.utc(2026, 1, 10));
      expect(b.resolve(date).majorSeason.start, DateTime.utc(2026, 1, 5));
      expect(info.star.itemId, 'st1');
    });

    test('منطقة بلا استعارة: dururRegionId = regionId', () {
      final info = a.resolve(DateTime(2026, 3, 3));
      expect(info.dururRegionId, 'a');
      expect(info.borrowsDurur, isFalse);
    });

    test('كل يوم 2025–2040 متصل، و29 فبراير يتبع قاعدة المُعيرة', () {
      for (final y in [2025, 2028, 2040]) {
        final days = YearIndex(c, y).days;
        for (var i = 0; i < days.length; i++) {
          expectConsistent(days[i]);
          if (i > 0) expectContinuous(days[i - 1], days[i]);
          expect(days[i].dar.record, same(b.resolve(days[i].date).dar.record));
        }
      }
      final feb29 = c.resolve(DateTime(2028, 2, 29));
      expect(
        feb29.dar.record,
        same(c.resolve(DateTime(2028, 2, 28)).dar.record),
      );
    });

    test('بناء المحرك بلا جدول المُعيرة أو بجدول خاطئ ← خطأ', () {
      final region = t.region('c')!;
      final table = t.regionTables['c']!;
      expect(
        () => CalendarEngine(region: region, table: table),
        throwsArgumentError,
      );
      expect(
        () => CalendarEngine(
          region: region,
          table: table,
          dururRegion: t.region('a'),
          dururTable: t.regionTables['a'],
        ),
        throwsArgumentError,
      );
      expect(
        () => CalendarEngine(
          region: t.region('a')!,
          table: t.regionTables['a']!,
          dururRegion: t.region('b'),
          dururTable: t.regionTables['b'],
        ),
        throwsArgumentError,
      );
    });
  });

  group('المدقق', () {
    const v = TableValidator();

    test('استعارة سليمة تمر؛ ومسودتها تمنع الإطلاق', () {
      expect(v.validate(borrowingTables()).errors, isEmpty);
      final draftBorrow = borrowingTables(
        edit: (c, _) => c['dururBorrow'] = borrow('b', approval: draft),
      );
      expect(v.validate(draftBorrow).errors, isEmpty);
      final release = v.validate(draftBorrow, release: true);
      expect(release.errors.join(), contains('dururBorrow'));
    });

    test('درور خاصة واستعارة معاً ← خطأ', () {
      final r = v.validate(
        borrowingTables(
          edit: (c, _) => c['durur'] = [dar('01-05', 1, 'أ', 's1')],
        ),
      );
      expect(r.errors.join(), contains('أحدهما فقط'));
    });

    test('لا درور ولا استعارة ← الطبقة فارغة', () {
      final r = v.validate(
        borrowingTables(edit: (c, _) => c.remove('dururBorrow')),
      );
      expect(r.errors.join(), contains('durur: الطبقة فارغة'));
    });

    test('المُعيرة غير موجودة، أو المنطقة نفسها', () {
      expect(
        v
            .validate(
              borrowingTables(edit: (c, _) => c['dururBorrow'] = borrow('zz')),
            )
            .errors
            .join(),
        contains('غير موجودة'),
      );
      expect(
        v
            .validate(
              borrowingTables(edit: (c, _) => c['dururBorrow'] = borrow('c')),
            )
            .errors
            .join(),
        contains('من نفسها'),
      );
    });

    test('سلسلة استعارة (d تستعير من c المستعيرة) ← خطأ', () {
      final r = v.validate(
        borrowingTables(
          edit: (_, all) {
            final d = all['d']! as Map<String, Object?>;
            d['durur'] = <Object?>[];
            d['dururBorrow'] = borrow('c');
          },
        ),
      );
      expect(r.errors.join(), contains('سلاسل الاستعارة'));
    });
  });

  group('البيانات التجريبية (قرار عرض السعودية)', () {
    test(
      'نجد تستعير درور الإمارات وعُمان مع سطر ثابت، والدَّرّ منها',
      () async {
        final tables = await loadAssetTables();
        final najd = tables.regionTables['najd']!;
        expect(najd.durur, isEmpty);
        expect(najd.dururBorrow?.fromRegionId, 'uae_oman');
        expect(najd.dururBorrow!.note.ar, contains('ليس من التقويم النجدي'));
        for (final id in ['kuwait', 'uae_oman', 'region4']) {
          expect(tables.regionTables[id]!.borrowsDurur, isFalse, reason: id);
        }
        final engine = CalendarEngine.fromTables(tables, 'najd');
        final lender = CalendarEngine.fromTables(tables, 'uae_oman');
        final date = DateTime(2026, 10, 2);
        final info = engine.resolve(date);
        expect(info.dururRegionId, 'uae_oman');
        expect(info.dar.record, same(lender.resolve(date).dar.record));
        expect(info.majorSeason.itemId, isNotEmpty);
        expect(info.star.start, isNot(lender.resolve(date).star.start));
      },
    );
  });
}
