import 'package:durur/src/astronomy/heliacal.dart';
import 'package:durur/src/domain/item.dart';
import 'package:durur/src/domain/month_day.dart';
import 'package:durur/src/domain/region_table.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/notifications/notification_planner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

Future<void> main() async {
  final tables = await loadAssetTables();
  const planner = NotificationPlanner();
  final kuwait = CalendarEngine.fromTables(tables, 'kuwait');
  final najd = CalendarEngine.fromTables(tables, 'najd');

  // تواريخ فلكية ثابتة للاختبار (تختلف عمداً عن الجدول: 08-27 و06-10).
  HeliacalDates fixedHeliacal(int year) => HeliacalDates(
    suhail: DateTime.utc(year, 8, 21),
    thurayya: DateTime.utc(year, 6, 5),
  );

  List<PlannedNotification> plan({
    required DateTime now,
    CalendarEngine? engine,
    Map<String, Item>? items,
    HeliacalDates? Function(int)? heliacal,
    bool important = true,
    bool dar = false,
  }) => planner.plan(
    now: now,
    engine: engine ?? kuwait,
    items: items ?? tables.items,
    heliacal: heliacal ?? fixedHeliacal,
    important: important,
    dar: dar,
  );

  String idOf(PlannedNotification p) => switch (p.subject) {
    ItemSubject(:final item) => item.id,
    DarSubject(:final record) => 'dar:${record.start}',
  };

  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('المواسم المهمة (مفعّل افتراضياً)', () {
    test('ستة مواسم مهمة في سنة: الجدول للمواسم، والحساب الفلكي لسهيل والثريا',
        () {
      final result = plan(now: DateTime(2026, 10, 2, 12));
      final byId = {for (final p in result) idOf(p): p.date};
      expect(byId.keys.toSet(), {
        'suhail',
        'thurayya',
        'wasm',
        'murabbaniya',
        'bard_ajayiz',
        'jamrat_qaiz',
      });
      // من جدول الكويت (assets/tables/regions/kuwait.json).
      expect(byId['wasm'], d(2026, 10, 19));
      expect(byId['murabbaniya'], d(2026, 12, 10));
      expect(byId['bard_ajayiz'], d(2027, 2, 25));
      expect(byId['jamrat_qaiz'], d(2027, 7, 18));
      // من الحساب الفلكي (لا من الجدول 06-10 و08-27).
      expect(byId['thurayya'], d(2027, 6, 5));
      expect(byId['suhail'], d(2027, 8, 21));
      for (final p in result) {
        expect(p.kind, NotificationKind.important);
        final s = p.subject as ItemSubject;
        expect(s.heliacal, s.item.dateMethod == DateMethod.heliacal);
      }
    });

    test('الساعة 08:00 بتوقيت الجهاز في يوم البداية (معيار 3)', () {
      for (final p in plan(now: DateTime(2026, 1, 1))) {
        expect(p.fireAt, DateTime(p.date.year, p.date.month, p.date.day, 8));
        expect(p.fireAt.isUtc, isFalse);
      }
    });

    test('معيار 9: يوم قبل الوسم ← تنبيه الوسم في اليوم التالي 8:00', () {
      final result = plan(now: DateTime(2026, 10, 18, 21));
      final wasm = result.firstWhere((p) => idOf(p) == 'wasm');
      expect(wasm.fireAt, DateTime(2026, 10, 19, 8));
      expect(result.first, same(wasm));
    });

    test('يوم البداية نفسه: قبل 8:00 وحتى 9:00 (هامش التأخر) يبقى في الخطة، '
        'وبعدها لا', () {
      for (final t in [
        DateTime(2026, 10, 19, 7, 59),
        DateTime(2026, 10, 19, 8),
        DateTime(2026, 10, 19, 8, 59),
      ]) {
        final wasm = plan(now: t).where((p) => idOf(p) == 'wasm');
        expect(wasm, hasLength(1), reason: '$t');
        expect(wasm.single.fireAt, DateTime(2026, 10, 19, 8));
      }
      final after = plan(now: DateTime(2026, 10, 19, 9));
      expect(after.where((p) => idOf(p) == 'wasm'), isEmpty);
      expect(NotificationPlanner.lateMargin, const Duration(hours: 1));
    });

    test('الأفق 365 يوماً: لا شيء بعده، ولا شيء قبل اليوم', () {
      final now = DateTime(2026, 10, 20, 9); // بعد بداية الوسم بيوم
      final result = plan(now: now);
      for (final p in result) {
        expect(p.date.isBefore(d(2026, 10, 20)), isFalse);
        expect(p.date.isAfter(d(2027, 10, 19)), isFalse);
      }
      // الوسم القادم 2027-10-19 هو اليوم الأخير في الأفق.
      expect(
        result.where((p) => idOf(p) == 'wasm').single.date,
        d(2027, 10, 19),
      );
    });

    test('تعذّر الحساب الفلكي (null) ← تاريخ بدايته في جدول المنطقة', () {
      final result = plan(
        now: DateTime(2026, 1, 1),
        heliacal: (_) => null,
      );
      final byId = {for (final p in result) idOf(p): p};
      expect(byId['suhail']!.date, d(2026, 8, 27));
      expect(byId['thurayya']!.date, d(2026, 6, 10));
      expect((byId['suhail']!.subject as ItemSubject).heliacal, isFalse);
    });
  });

  group('بداية كل دَرّ (مطفأ افتراضياً)', () {
    test('المفتاحان مستقلان (معيار 2)', () {
      final now = DateTime(2026, 3, 1);
      final onlyImportant = plan(now: now);
      final onlyDar = plan(now: now, important: false, dar: true);
      expect(
        onlyImportant.every((p) => p.kind == NotificationKind.important),
        isTrue,
      );
      expect(onlyDar.every((p) => p.kind == NotificationKind.dar), isTrue);
      expect(onlyDar, hasLength(37)); // كل درور الكويت في سنة
      expect(plan(now: now, important: false), isEmpty);
      final both = plan(now: now, dar: true);
      expect(both, hasLength(onlyImportant.length + onlyDar.length));
    });

    test('تواريخ الدرور = بدايات سجلات الجدول', () {
      final starts = {
        for (final r in tables.regionTables['kuwait']!.durur) r.start,
      };
      for (final p in plan(now: DateTime(2026, 1, 1, 9), important: false, dar: true)) {
        final s = p.subject as DarSubject;
        expect(starts, contains(s.record.start));
        expect(p.date.month, s.record.start.month);
        expect(p.date.day, s.record.start.day);
        expect(s.regionId, 'kuwait');
      }
    });

    test('منطقة بلا درور (D50): لا تنبيهات دَرّ مهما كان المفتاح', () {
      expect(najd.hasDurur, isFalse);
      final onlyDar = plan(
        now: DateTime(2026, 1, 1),
        engine: najd,
        important: false,
        dar: true,
      );
      expect(onlyDar, isEmpty);
      final both = plan(now: DateTime(2026, 1, 1), engine: najd, dar: true);
      expect(both, isNotEmpty);
      expect(both.every((p) => p.kind == NotificationKind.important), isTrue);
    });
  });

  group('الحد والترتيب والمعرّفات', () {
    test('لا يتجاوز 60 (حد آيفون)، ويُبقي الأقرب زمنياً', () {
      // جدول اصطناعي: دَرّ كل 5 أيام (73 في السنة) + المواسم المهمة > 60.
      final base = tables.regionTables['kuwait']!;
      final template = base.durur.first;
      final dense = RegionTable(
        regionId: 'kuwait',
        durur: [
          for (var i = 0; i < 73; i++)
            DarRecord(
              regionId: 'kuwait',
              start: MonthDay.of(DateTime.utc(2025, 1, 1 + i * 5)),
              number: i + 1,
              name: template.name,
              seasonId: template.seasonId,
              weather: template.weather,
              weatherNote: template.weatherNote,
              source: template.source,
              approval: template.approval,
            ),
        ],
        majorSeasons: base.majorSeasons,
        stars: base.stars,
        weatherSeasons: base.weatherSeasons,
      );
      final engine = CalendarEngine(region: kuwait.region, table: dense);
      final now = DateTime(2026, 1, 1);
      final full = plan(now: now, engine: engine, dar: true);
      expect(full, hasLength(NotificationPlanner.maxPending));
      // المقصوص كله بعد آخر مجدول (يُبقي الأقرب).
      final last = full.last.date;
      expect(last.isBefore(d(2026, 12, 31)), isTrue);
      final untrimmedDars = 73;
      expect(
        full.where((p) => p.kind == NotificationKind.dar).length,
        lessThan(untrimmedDars),
      );
      for (var i = 1; i < full.length; i++) {
        expect(full[i].date.isBefore(full[i - 1].date), isFalse);
      }
    });

    test('ترتيب زمني، معرّفات فريدة yyyymmdd*100+slot ضمن int32', () {
      final result = plan(now: DateTime(2026, 1, 1), dar: true);
      expect(result.length, lessThanOrEqualTo(60));
      final ids = <int>{};
      for (var i = 0; i < result.length; i++) {
        final p = result[i];
        if (i > 0) expect(p.date.isBefore(result[i - 1].date), isFalse);
        final ymd = p.date.year * 10000 + p.date.month * 100 + p.date.day;
        expect(p.id ~/ 100, ymd);
        expect(p.id % 100, lessThan(100));
        expect(p.id, lessThan(1 << 31));
        expect(ids.add(p.id), isTrue);
      }
    });

    test('معيار 7: لا يتكرر (الموضوع، اليوم)', () {
      final result = plan(now: DateTime(2026, 1, 1), dar: true);
      final keys = {for (final p in result) (idOf(p), p.date)};
      expect(keys, hasLength(result.length));
    });

    test('حتمي: المدخلات نفسها ← الخطة نفسها', () {
      final a = plan(now: DateTime(2026, 5, 5, 10), dar: true);
      final b = plan(now: DateTime(2026, 5, 5, 10), dar: true);
      expect(a.map((p) => p.id), b.map((p) => p.id));
      expect(a.map(idOf), b.map(idOf));
    });

    test('كل المناطق وكل سنوات 2025–2040: ضمن الحد والأفق', () {
      for (final regionId in tables.regionTables.keys) {
        final engine = CalendarEngine.fromTables(tables, regionId);
        for (var year = 2025; year <= 2040; year++) {
          final result = plan(
            now: DateTime(year, 7, 1, 9),
            engine: engine,
            dar: true,
          );
          expect(result.length, lessThanOrEqualTo(60), reason: '$regionId $year');
          expect(result, isNotEmpty);
        }
      }
    });
  });

  test('heliacalDateOf: سهيل والثريا فقط', () {
    final h = fixedHeliacal(2026);
    expect(heliacalDateOf('suhail', h), h.suhail);
    expect(heliacalDateOf('thurayya', h), h.thurayya);
    expect(heliacalDateOf('wasm', h), isNull);
    expect(heliacalDateOf('suhail', null), isNull);
  });

  test('Tables المحمّلة تحوي العناصر الستة المهمة', () {
    final Tables t = tables;
    expect(
      t.items.values.where((i) => i.important).map((i) => i.id).toSet(),
      {'suhail', 'thurayya', 'wasm', 'murabbaniya', 'bard_ajayiz', 'jamrat_qaiz'},
    );
  });
}
