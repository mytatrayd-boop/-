import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/features/home/season_events.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// العدّاد وبطاقة «القادم» (DESIGN R2.8): من الجداول فقط.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  final najd = CalendarEngine.fromTables(tables, 'najd');

  List<SeasonEvent> events(
    DateTime from, {
    DateTime? Function(String, int)? rising,
  }) => seasonEvents(
    from: from,
    resolve: najd.resolve,
    items: tables.items,
    rising: rising,
  );

  test('الرياض 7 أكتوبر 2026: باقي ٩ أيام على دخول الوسم (الجمعة ١٦ أكتوبر)', () {
    final all = events(DateTime(2026, 10, 7));
    final target = countdownEvent(all)!;
    expect(target.kind, SeasonEventKind.weatherSeason);
    expect(target.itemId, 'wasm');
    expect(target.days, 9);
    expect(target.date, DateTime(2026, 10, 16));
    expect(target.date.weekday, DateTime.friday);
  });

  test('القادم: الدَّرّ التالي، والموسم الكبير التالي، وأقرب موسم جو غير الهدف', () {
    final all = events(DateTime(2026, 10, 7));
    final rows = upcomingEvents(all, countdownEvent(all));
    expect(rows, hasLength(3));
    expect(rows[0].kind, SeasonEventKind.dar);
    expect(rows[0].dar!.name.ar, 'السبعين');
    expect(rows[0].days, 3);
    expect(rows[1].kind, SeasonEventKind.majorSeason);
    expect(rows[1].itemId, 'shita');
    expect(rows[1].days, 47);
    expect(rows[2].itemId, 'murabbaniya');
    expect(rows[2].days, 61);
    // مرتبة بالأقرب، وكلها بعد اليوم المعروض.
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].days, greaterThanOrEqualTo(rows[i - 1].days));
    }
    expect(rows.every((e) => e.days > 0), isTrue);
  });

  test('يوم البداية نفسه: الحدث بيوم 0 (دخل الوسم اليوم)', () {
    final target = countdownEvent(events(DateTime(2026, 10, 16)))!;
    expect(target.itemId, 'wasm');
    expect(target.days, 0);
  });

  test('عند التساوي: موسم الجو ← الطالع ← الموسم الكبير', () {
    final all = events(DateTime(2026, 1, 1));
    for (var i = 1; i < all.length; i++) {
      if (all[i].days == all[i - 1].days) {
        expect(
          all[i].kind.index,
          greaterThanOrEqualTo(all[i - 1].kind.index),
        );
      }
    }
  });

  test('سهيل والثريا: الطلوع المحسوب للمدينة بدل بداية سجلهما في الجدول', () {
    final from = DateTime(2026, 8, 1);
    final table = events(from);
    final suhailTable = table.where((e) => e.itemId == 'suhail').toList();
    expect(suhailTable, isNotEmpty);
    expect(suhailTable.first.computed, isFalse);

    final computed = events(
      from,
      rising: (id, year) =>
          id == 'suhail' && year == 2026 ? DateTime.utc(2026, 8, 20) : null,
    );
    final suhail = computed.where((e) => e.itemId == 'suhail').toList();
    expect(suhail, hasLength(1));
    expect(suhail.single.computed, isTrue);
    expect(suhail.single.date, DateTime(2026, 8, 20));
    expect(suhail.single.days, 19);
    expect(suhail.single.kind, SeasonEventKind.star);
  });

  test('العدّاد لا يعدّ الدرور', () {
    for (final day in [DateTime(2026, 3, 1), DateTime(2026, 7, 1)]) {
      expect(countdownEvent(events(day))!.kind, isNot(SeasonEventKind.dar));
    }
  });

  test('سهيل: تعذّر الحساب (null) ← تُعدّ بداية سجله في الجدول', () {
    final from = DateTime(2026, 8, 1);
    final table = events(from).where((e) => e.itemId == 'suhail').toList();
    final fallback = events(
      from,
      rising: (id, year) => null,
    ).where((e) => e.itemId == 'suhail').toList();
    expect(fallback, isNotEmpty);
    expect(fallback.first.computed, isFalse);
    expect(fallback.first.date, table.first.date);
  });
}
