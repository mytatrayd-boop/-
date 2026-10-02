import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/domain/item.dart';
import 'package:durur/src/domain/month_day.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/formatting/digits.dart';
import 'package:durur/src/notifications/notification_content.dart';
import 'package:durur/src/notifications/notification_planner.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:durur/src/routing/app_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_notification_scheduler.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  final l10n = lookupAppLocalizations(const Locale('ar'));

  group('النص والحمولة (DESIGN 8.9)', () {
    PlannedNotification find(
      String regionId,
      bool Function(PlannedNotification) where, {
      bool dar = false,
    }) => const NotificationPlanner()
        .plan(
          now: DateTime(2026, 1, 1),
          engine: CalendarEngine.fromTables(tables, regionId),
          items: tables.items,
          heliacal: (_) => null,
          important: !dar,
          dar: dar,
        )
        .firstWhere(where);

    ScheduledNotification build(PlannedNotification p, String cityId) {
      final city = tables.city(cityId)!;
      return buildScheduledNotification(
        p,
        l10n: l10n,
        tables: tables,
        city: city,
        region: tables.region(city.regionId)!,
      );
    }

    bool isItem(PlannedNotification p, String id) =>
        p.subject is ItemSubject && (p.subject as ItemSubject).item.id == id;

    test('موسم مهم: «دخل الوسم اليوم في الكويت»، والحمولة صفحة الموسم', () {
      final n = build(find('kuwait', (p) => isItem(p, 'wasm')), 'kuwait_city');
      expect(n.title, 'دخل الوسم اليوم في الكويت');
      expect(n.body, 'اضغط لتعرف عن الوسم ومثله الشعبي.');
      expect(n.payload, '/item/wasm?from=2026-10-19');
      expect(n.fireAt, DateTime(2026, 10, 19, 8));
      expect(isNotificationPayload(n.payload), isTrue);
    });

    test('سهيل بالحساب الفلكي: «طلع سهيل اليوم في الرياض»', () {
      final p = const NotificationPlanner()
          .plan(
            now: DateTime(2026, 1, 1),
            engine: CalendarEngine.fromTables(tables, 'najd'),
            items: tables.items,
            heliacal: (y) => null,
            important: true,
            dar: false,
          )
          .firstWhere((p) => isItem(p, 'suhail'));
      final heliacal = PlannedNotification(
        id: p.id,
        date: p.date,
        kind: p.kind,
        subject: ItemSubject(tables.items['suhail']!, heliacal: true),
      );
      final n = build(heliacal, 'riyadh');
      expect(n.title, 'طلع سهيل اليوم في الرياض');
      expect(n.body, 'أول ظهوره قبل الفجر. اضغط لتعرف عنه.');
      expect(n.payload, startsWith('/item/suhail?from='));
    });

    test('الثريا بالمؤنث (§13 «جنس النجم»): «طلعت الثريا اليوم في الرياض»',
        () {
      final thurayya = tables.items['thurayya']!;
      expect(thurayya.gender, StarGender.feminine);
      final p = find('najd', (p) => isItem(p, 'thurayya'));
      final n = build(
        PlannedNotification(
          id: p.id,
          date: p.date,
          kind: p.kind,
          subject: ItemSubject(thurayya, heliacal: true),
        ),
        'riyadh',
      );
      expect(n.title, 'طلعت الثريا اليوم في الرياض');
      expect(n.body, 'أول ظهورها قبل الفجر. اضغط لتعرف عنها.');
      expect(n.title, l10n.notifStarTitle('f', 'الثريا', 'الرياض'));
      expect(n.body, l10n.notifStarBody('f'));
    });

    test('بداية دَرّ: العنوان من سجله ومئته، والحمولة /dar/<المنطقة>/<MM-DD>',
        () {
      final p = find('kuwait', (_) => true, dar: true);
      final s = p.subject as DarSubject;
      final n = build(p, 'kuwait_city');
      final hundred = tables.items[s.record.seasonId]!.name.ar;
      expect(n.title, 'بدأ دَرّ ${s.record.name.ar} من $hundred');
      expect(n.body, startsWith('الجو المعتاد: '));
      expect(
        n.payload,
        AppRoutes.dar('kuwait', s.record.start, from: p.date),
      );
      expect(n.payload, matches(RegExp(r'^/dar/kuwait/\d\d-\d\d\?from=')));
      expect(n.kind, NotificationKind.dar);
    });

    test('الدَّرّ المستعار (D24): notifDarTitleBorrowed باسم المُعيرة لا «في نجد»',
        () {
      final p = find('najd', (_) => true, dar: true);
      final s = p.subject as DarSubject;
      expect(s.borrowed, isTrue);
      expect(s.dururRegionId, 'uae_oman');
      final n = build(p, 'riyadh');
      final lender = tables.region('uae_oman')!.name.ar;
      expect(lender, 'الإمارات وعُمان');
      expect(
        n.title,
        l10n.notifDarTitleBorrowed(
          s.record.name.ar,
          tables.items[s.record.seasonId]!.name.ar,
          lender,
        ),
      );
      expect(n.title, endsWith('حسب حساب الإمارات وعُمان'));
      expect(n.title, isNot(contains('نجد')));
      expect(n.payload, startsWith('/dar/uae_oman/'));
    });

    test('الحمولة الصالحة فقط تُفتح', () {
      for (final ok in [
        '/item/wasm',
        '/item/wasm?from=2026-10-19',
        '/dar/kuwait/10-01?from=2026-10-01',
      ]) {
        expect(isNotificationPayload(ok), isTrue, reason: ok);
      }
      for (final bad in [
        null,
        '',
        '/',
        '/settings',
        '/item/',
        '/dar/kuwait',
        'https://example.com/item/wasm',
        '//evil/item/x',
        '/item/a/b',
        'item/wasm',
        'dar/kuwait/10-01',
      ]) {
        expect(isNotificationPayload(bad), isFalse, reason: bad);
      }
      // المسار يُبنى بـ AppRoutes نفسها التي يقرؤها الموجّه.
      expect(
        AppRoutes.dar('kuwait', const MonthDay(10, 1)),
        '/dar/kuwait/10-01',
      );
    });
  });

  group('المزامنة (notificationSyncProvider)', () {
    late FakeNotificationScheduler scheduler;
    late DateTime now;

    Future<ProviderContainer> start(
      Map<String, Object> saved, {
      Tables? withTables,
    }) async {
      final prefs = await fakePrefs(saved);
      scheduler = FakeNotificationScheduler();
      final c = ProviderContainer(
        overrides: [
          ...appOverrides(prefs, withTables ?? tables, [
            fakeScheduler(scheduler),
          ]),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      await c.read(tablesProvider.future);
      c.listen(notificationSyncProvider, (_, _) {});
      await settle();
      return c;
    }

    setUp(() => now = DateTime(2026, 10, 2, 10));

    Iterable<String> titles() => scheduler.pending.map((n) => n.title);

    test('عند الفتح: تُجدول المواسم المهمة فقط (الافتراضي)', () async {
      await start(savedCity('kuwait_city'));
      expect(scheduler.replaceCalls, 1);
      expect(scheduler.pending, hasLength(6));
      expect(scheduler.pending.every((n) => n.kind == NotificationKind.important),
          isTrue);
      expect(scheduler.scheduledTimezone, 'Asia/Riyadh');
      expect(scheduler.channels, (important: 'المواسم المهمة', dar: 'بداية كل دَرّ'));
      expect(scheduler.pending.first.title, 'دخل الوسم اليوم في الكويت');
    });

    test('سهيل والثريا من الحساب الفلكي لمدينة المستخدم', () async {
      final c = await start(savedCity('kuwait_city'));
      final h2027 = c.read(currentHeliacalProvider(2027))!;
      final suhail = scheduler.pending.firstWhere(
        (n) => n.payload.startsWith('/item/suhail'),
      );
      expect(suhail.title, 'طلع سهيل اليوم في مدينة الكويت');
      expect(
        suhail.fireAt,
        DateTime(h2027.suhail!.year, h2027.suhail!.month, h2027.suhail!.day, 8),
      );
    });

    test('المنطقة المستعيرة: كل تنبيهات الدرور المجدولة بعنوان المُعيرة',
        () async {
      final c = await start(savedCity('riyadh'));
      await c.read(settingsProvider.notifier).setNotifyDar(true);
      await settle();
      final dar =
          scheduler.pending.where((n) => n.kind == NotificationKind.dar);
      expect(dar, isNotEmpty);
      for (final n in dar) {
        expect(n.title, endsWith('حسب حساب الإمارات وعُمان'), reason: n.title);
        expect(n.title, isNot(contains('نجد')));
        expect(n.payload, startsWith('/dar/uae_oman/'));
      }
    });

    test('DESIGN 8.7: تغيير «الأرقام» يعيد الجدولة بصمت', () async {
      final c = await start(savedCity('kuwait_city'));
      expect(scheduler.replaceCalls, 1);
      final before = scheduler.pending.map((n) => n.fingerprint).toList();
      await c.read(settingsProvider.notifier).setDigits(DigitStyle.latin);
      await settle();
      expect(scheduler.replaceCalls, 2);
      // بصمت: لا حالة فشل ولا طلب إذن، والخطة نفسها كاملة.
      expect(c.read(notificationSyncProvider), NotificationSyncStatus.scheduled);
      expect(scheduler.permissionRequests, 0);
      expect(scheduler.pending.map((n) => n.fingerprint), before);
      // الرجوع للإعداد الأول يعيدها مرة أخرى، وتكرار القيمة نفسها لا.
      await c.read(settingsProvider.notifier).setDigits(DigitStyle.arabicIndic);
      await settle();
      expect(scheduler.replaceCalls, 3);
      await c.read(settingsProvider.notifier).setDigits(DigitStyle.arabicIndic);
      await settle();
      expect(scheduler.replaceCalls, 3);
    });

    test('تغيير المفتاحين يعيد الجدولة، وكل مفتاح مستقل', () async {
      final c = await start(savedCity('kuwait_city'));
      await c.read(settingsProvider.notifier).setNotifyDar(true);
      await settle();
      expect(scheduler.replaceCalls, 2);
      expect(scheduler.pending, hasLength(6 + 37));
      await c.read(settingsProvider.notifier).setNotifyImportant(false);
      await settle();
      expect(scheduler.replaceCalls, 3);
      expect(scheduler.pending, hasLength(37));
      expect(scheduler.pending.every((n) => n.kind == NotificationKind.dar),
          isTrue);
      await c.read(settingsProvider.notifier).setNotifyDar(false);
      await settle();
      expect(scheduler.pending, isEmpty);
    });

    test('معيار 6: تغيير المدينة يعيد الجدولة حسب المنطقة الجديدة', () async {
      final c = await start(savedCity('kuwait_city'));
      expect(titles(), contains('دخل الوسم اليوم في الكويت'));
      await c.read(settingsProvider.notifier).selectCity('muscat');
      await settle();
      expect(scheduler.replaceCalls, 2);
      expect(titles(), contains('دخل الوسم اليوم في الإمارات وعُمان'));
      expect(titles(), isNot(contains('دخل الوسم اليوم في الكويت')));
    });

    test('إعادة تحميل الجداول (§16.5) تعيد الجدولة', () async {
      final c = await start(savedCity('kuwait_city'));
      c.invalidate(tablesProvider);
      await c.read(tablesProvider.future);
      await settle();
      // الخطة نفسها والجداول جديدة: لا تكرار، والنتيجة حتمية.
      expect(scheduler.pending, hasLength(6));
      expect(
        scheduler.replaceCalls,
        1,
        reason: 'خطة مطابقة لا تُعاد جدولتها',
      );
      final ids = scheduler.pending.map((n) => n.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('العودة للواجهة: لا شيء تغيّر ← لا إعادة؛ منطقة زمنية جديدة ← إعادة',
        () async {
      final c = await start(savedCity('kuwait_city'));
      await c.read(notificationSyncProvider.notifier).sync();
      expect(scheduler.replaceCalls, 1);
      scheduler.timezone = 'Asia/Dubai';
      await c.read(notificationSyncProvider.notifier).sync();
      expect(scheduler.replaceCalls, 2);
      expect(scheduler.scheduledTimezone, 'Asia/Dubai');
    });

    test('يوم جديد (اليوم يتغير) ← خطة جديدة تبدأ منه', () async {
      final c = await start(savedCity('kuwait_city'));
      now = DateTime(2026, 10, 20, 9); // بعد بداية الوسم
      c.read(todayProvider.notifier).refresh();
      await settle();
      expect(scheduler.replaceCalls, 2);
      expect(
        scheduler.pending.where((n) => n.payload.startsWith('/item/wasm')).single.fireAt,
        DateTime(2027, 10, 19, 8),
      );
    });

    test('فشل الجدولة ← الحالة failed، ثم نجاح لاحق ← scheduled', () async {
      final prefs = await fakePrefs(savedCity('kuwait_city'));
      scheduler = FakeNotificationScheduler(permitted: true, failSchedule: true);
      final c = ProviderContainer(
        overrides: [
          ...appOverrides(prefs, tables, [fakeScheduler(scheduler)]),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      await c.read(tablesProvider.future);
      c.listen(notificationSyncProvider, (_, _) {});
      await settle();
      expect(c.read(notificationSyncProvider), NotificationSyncStatus.failed);
      scheduler.failSchedule = false;
      await c.read(notificationSyncProvider.notifier).sync();
      expect(c.read(notificationSyncProvider), NotificationSyncStatus.scheduled);
    });

    test('آيفون بلا إذن (رفض الإضافة): ليس فشلاً، ومنح الإذن يعيد الجدولة',
        () async {
      final prefs = await fakePrefs(savedCity('kuwait_city'));
      scheduler = FakeNotificationScheduler(failWithoutPermission: true);
      final c = ProviderContainer(
        overrides: [
          ...appOverrides(prefs, tables, [fakeScheduler(scheduler)]),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      await c.read(tablesProvider.future);
      c.listen(notificationSyncProvider, (_, _) {});
      await settle();
      expect(scheduler.replaceCalls, 1);
      expect(scheduler.pending, isEmpty);
      expect(c.read(notificationSyncProvider), NotificationSyncStatus.idle);

      // منح الإذن ← جدولة تلقائية بلا أي تغيير آخر.
      await c.read(notificationPermissionProvider.notifier).request();
      await settle();
      expect(scheduler.replaceCalls, 2);
      expect(scheduler.pending, hasLength(6));
      expect(c.read(notificationSyncProvider), NotificationSyncStatus.scheduled);
    });

    test('الإذن ممنوح ثم فشل حقيقي ← failed', () async {
      final prefs = await fakePrefs(savedCity('kuwait_city'));
      scheduler = FakeNotificationScheduler(permitted: true, failSchedule: true);
      final c = ProviderContainer(
        overrides: [
          ...appOverrides(prefs, tables, [fakeScheduler(scheduler)]),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      await c.read(tablesProvider.future);
      c.listen(notificationSyncProvider, (_, _) {});
      await settle();
      expect(c.read(notificationSyncProvider), NotificationSyncStatus.failed);
    });

    test('بلا مدينة: لا تنبيهات (إلغاء الكل)', () async {
      await start({});
      expect(scheduler.pending, isEmpty);
    });

    test('المفاتيح محفوظة على الجهاز بقيمها الافتراضية الصحيحة', () async {
      final c = await start(savedCity('kuwait_city'));
      final s = c.read(settingsProvider);
      expect(s.notifyImportant, isTrue);
      expect(s.notifyDar, isFalse);
      await c.read(settingsProvider.notifier).setNotifyDar(true);
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getBool(SettingsRepository.notifyDarKey), isTrue);
      expect(prefs.containsKey(SettingsRepository.notifyImportantKey), isFalse);
    });
  });

  group('إذن التنبيهات', () {
    test('القراءة والطلب والرفض', () async {
      final scheduler = FakeNotificationScheduler(grantOnRequest: false);
      final c = ProviderContainer(
        overrides: [
          ...appOverrides(await fakePrefs(), tables, [fakeScheduler(scheduler)]),
        ],
      );
      addTearDown(c.dispose);
      expect(await c.read(notificationPermissionProvider.future), isFalse);
      expect(
        await c.read(notificationPermissionProvider.notifier).request(),
        isFalse,
      );
      expect(scheduler.permissionRequests, 1);
      scheduler.grantOnRequest = true;
      expect(
        await c.read(notificationPermissionProvider.notifier).request(),
        isTrue,
      );
      expect(c.read(notificationPermissionProvider).value, isTrue);
      // تغيّر من إعدادات الجهاز يُكتشف عند العودة.
      scheduler.permitted = false;
      await c.read(notificationPermissionProvider.notifier).refresh();
      expect(c.read(notificationPermissionProvider).value, isFalse);
    });
  });
}

/// يترك المستمعين والمهام المؤجلة تنتهي.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
