import 'dart:io';
import 'dart:typed_data';

import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:durur/src/updates/bundle_verifier.dart';
import 'package:durur/src/updates/data_updater.dart';
import 'package:durur/src/updates/update_config.dart';
import 'package:durur/src/updates/update_fetcher.dart';
import 'package:durur/src/updates/update_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_notification_scheduler.dart';
import 'update_test_kit.dart';

/// التحديث كاملاً بالمزوّدات (ARCHITECTURE §16.2–16.5، §16.9): القبول وإعادة
/// تحميل الجداول والهجري وإعادة جدولة التنبيهات، والرفض والبقاء على الحالي،
/// والتوقيت، وبلا إنترنت، والرجوع إلى المضمّن.
void main() {
  late TestSigner signer;
  late Tables embedded;

  /// الحزمة 1: تصحيح اسم «الوسم» (يظهر في عنوان تنبيهه).
  late Release fixedWasm;
  const fixedName = 'الوسم المصحّح';

  setUpAll(() async {
    signer = await TestSigner.generate();
    embedded = await loadAssetTables();
    fixedWasm = await buildRelease(
      signer,
      1,
      mutate: (f) {
        for (final item in f['items.json']! as List) {
          if ((item as Map)['id'] == 'wasm') item['name'] = {'ar': fixedName};
        }
      },
    );
  });

  late Directory dir;
  late FakeFetcher fetcher;
  late FakeNotificationScheduler scheduler;
  late SharedPreferences prefs;
  late DateTime now;
  final base = Uri.parse('https://example.test/durur-data/v1/');

  setUp(() async {
    dir = await tempSupportDir();
    fetcher = FakeFetcher();
    now = DateTime(2026, 10, 2, 10);
    prefs = await fakePrefs(savedCity('riyadh'));
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  UpdateStore store() => UpdateStore(() async => dir);
  UpdateState state() => UpdateState(prefs);

  /// «فتح التطبيق»: حاوية جديدة على الجهاز نفسه (prefs والمجلد).
  Future<ProviderContainer> open({
    Map<String, String>? keys,
    UpdateConfig config = const UpdateConfig(
      baseUrl: 'https://example.test/durur-data',
    ),
    Tables? embeddedTables,
    UpdateFetcher? using,
    UpdateStore? customStore,
  }) async {
    scheduler = FakeNotificationScheduler(permitted: true);
    final c = ProviderContainer(
      overrides: appOverrides(prefs, null, [
        fakeScheduler(scheduler),
        embeddedTablesLoaderProvider.overrideWithValue(
          () async => embeddedTables ?? embedded,
        ),
        updateStoreProvider.overrideWithValue(customStore ?? store()),
        updateFetcherProvider.overrideWithValue(using ?? fetcher),
        trustedKeysProvider.overrideWithValue(keys ?? signer.trustedKeys),
        updateConfigProvider.overrideWithValue(config),
        appBuildProvider.overrideWith((ref) async => 1),
        clockProvider.overrideWith((ref) => () => now),
      ]),
    );
    addTearDown(c.dispose);
    c.listen(notificationSyncProvider, (_, _) {});
    await c.read(tablesProvider.future);
    await settle();
    return c;
  }

  Future<UpdateOutcome> check(ProviderContainer c) async {
    final outcome = await c.read(dataUpdateProvider.notifier).maybeCheck();
    await c.read(tablesProvider.future);
    await settle();
    return outcome;
  }

  Iterable<String> titles() => scheduler.pending.map((n) => n.title);

  group('القبول', () {
    test('حزمة صحيحة ← تُثبَّت وتُعاد الجداول والهجري والتنبيهات', () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      final before = c.read(tablesProvider).value!;
      final hijriBefore = c.read(hijriCalendarProvider);
      expect(before.meta.dataSeq, 0);
      expect(titles(), isNot(contains(contains(fixedName))));
      final calls = scheduler.replaceCalls;

      expect(await check(c), UpdateOutcome.updated);

      // الطلبان فقط، بالمسارين الثابتين بلا معاملات.
      expect(fetcher.requests, [
        base.resolve('manifest.json'),
        base.resolve('bundle-1.json'),
      ]);
      final after = c.read(tablesProvider).value!;
      expect(after, isNot(same(before)));
      expect(after.meta.dataSeq, 1);
      expect(after.items['wasm']!.name.ar, fixedName);
      expect(after.hasUnapproved, isFalse);
      expect(c.read(hasUnapprovedDataProvider), isFalse);
      // الهجري من الحزمة الجديدة (§16.5).
      expect(c.read(hijriCalendarProvider), isNot(same(hijriBefore)));
      expect(c.read(hijriCalendarProvider), same(after.hijri));
      // إعادة الجدولة من الخطة الجديدة.
      expect(scheduler.replaceCalls, greaterThan(calls));
      expect(titles(), contains(contains(fixedName)));
      // الحالة المحفوظة.
      expect(state().highestSeq, 1);
      expect(state().lastCheckOk, now);
      expect(state().lastAttempt, now);
      expect(await store().read(), isNotNull);
      expect(c.read(dataUpdateProvider).outcome, UpdateOutcome.updated);
      expect(c.read(dataUpdateProvider).acceptedCount, 1);
    });

    test('الفتح التالي يحمّل الحزمة المثبّتة بلا شبكة', () async {
      fetcher.publish(fixedWasm, 1);
      await check(await open());
      fetcher
        ..requests.clear()
        ..failure = FetchFailure.network;

      final c = await open();
      expect(c.read(tablesProvider).value!.meta.dataSeq, 1);
      expect(titles(), contains(contains(fixedName)));
      // لم يحن موعد التحقق (7 أيام) ← لا طلب.
      expect(await check(c), UpdateOutcome.notDue);
      expect(fetcher.requests, isEmpty);
    });

    test('خادم HTTP محلي حقيقي (dart:io) من البداية للنهاية', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final paths = <String>[];
      server.listen((r) async {
        paths.add(r.uri.toString());
        final body = switch (r.uri.path) {
          '/durur-data/v1/manifest.json' => fixedWasm.manifest,
          '/durur-data/v1/bundle-1.json' => fixedWasm.bundle,
          _ => null,
        };
        if (body == null) r.response.statusCode = 404;
        if (body != null) r.response.add(body);
        await r.response.close();
      });
      final root = Uri.parse(
        'http://127.0.0.1:${server.port}/durur-data/v1/',
      );
      final c = await open(
        config: UpdateConfig.unchecked(root),
        using: HttpUpdateFetcher.allowingHttpForTesting(),
      );
      expect(await check(c), UpdateOutcome.updated);
      expect(paths, [
        '/durur-data/v1/manifest.json',
        '/durur-data/v1/bundle-1.json',
      ]);
      expect(c.read(tablesProvider).value!.meta.dataSeq, 1);
    });
  });

  group('الرفض ← البقاء على الحالي', () {
    Future<void> expectRejected(Release release, RejectReason reason) async {
      fetcher.publish(release, 1);
      final c = await open();
      final before = c.read(tablesProvider).value!;
      final calls = scheduler.replaceCalls;

      expect(await check(c), UpdateOutcome.failed);
      final updater = c.read(dataUpdaterProvider);
      expect(
        updater.lastError,
        isA<UpdateRejected>().having((e) => e.reason, 'reason', reason),
      );
      expect(c.read(tablesProvider).value, same(before));
      expect(scheduler.replaceCalls, calls);
      expect(await store().read(), isNull);
      expect(state().highestSeq, 0);
      expect(state().lastCheckOk, isNull);
      expect(state().lastAttempt, now);
    }

    test('توقيع خاطئ', () async {
      final other = await TestSigner.generate();
      await expectRejected(
        await buildRelease(other, 1),
        RejectReason.badSignature,
      );
    });

    test('بصمة خاطئة', () async {
      final bad = Uint8List.fromList(fixedWasm.bundle);
      bad[bad.length ~/ 2] ^= 1;
      await expectRejected(
        (manifest: fixedWasm.manifest, bundle: bad),
        RejectReason.hashMismatch,
      );
    });

    test('جداول لا تجتاز المدقق (سجل مسودة)', () async {
      await expectRejected(
        await buildRelease(
          signer,
          1,
          mutate: (f) => ((f['items.json']! as List).first as Map)['approval'] =
              {'status': 'draft', 'reviewer': null, 'date': null},
        ),
        RejectReason.invalidTables,
      );
    });

    test('هجري مزاح بيومين', () async {
      await expectRejected(
        await buildRelease(
          signer,
          1,
          mutate: (f) {
            final starts = hijriStarts(f);
            for (var i = 0; i < starts.length; i++) {
              starts[i] = isoPlusDays(starts[i]! as String, 2);
            }
          },
        ),
        RejectReason.hijriShift,
      );
    });

    test('حذف مدينة (المدينة المحفوظة)', () async {
      await expectRejected(
        await buildRelease(
          signer,
          1,
          mutate: (f) => (f['cities.json']! as List).removeWhere(
            (c) => (c as Map)['id'] == 'riyadh',
          ),
        ),
        RejectReason.removedIds,
      );
    });

    test('بعد الفشل: لا محاولة قبل 24 ساعة، ثم محاولة', () async {
      fetcher.failure = FetchFailure.network;
      final c = await open();
      expect(await check(c), UpdateOutcome.failed);
      expect(fetcher.requests, hasLength(1));

      now = now.add(const Duration(hours: 23));
      expect(await check(c), UpdateOutcome.notDue);
      expect(fetcher.requests, hasLength(1));

      now = now.add(const Duration(hours: 1));
      fetcher.failure = null;
      fetcher.publish(fixedWasm, 1);
      expect(await check(c), UpdateOutcome.updated);
      expect(c.read(tablesProvider).value!.meta.dataSeq, 1);
    });
  });

  group('الرقم والتوقيت', () {
    test('seq مساوٍ لآخر مقبول ← لا تنزيل (نجاح بلا جديد)، ثم 7 أيام', () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      expect(await check(c), UpdateOutcome.updated);
      fetcher.requests.clear();

      now = now.add(const Duration(days: 7));
      expect(await check(c), UpdateOutcome.upToDate);
      expect(fetcher.requests, [base.resolve('manifest.json')]);
      expect(state().lastCheckOk, now);

      now = now.add(const Duration(days: 6, hours: 23));
      expect(await check(c), UpdateOutcome.notDue);
      expect(fetcher.requests, hasLength(1));

      now = now.add(const Duration(hours: 1));
      expect(await check(c), UpdateOutcome.upToDate);
      expect(fetcher.requests, hasLength(2));
    });

    test('seq أقدم من آخر مقبول ← لا تنزيل ولا تغيير', () async {
      await prefs.setInt(UpdateState.highestSeqKey, 5);
      fetcher.publish(await buildRelease(signer, 3), 3);
      final c = await open();
      expect(await check(c), UpdateOutcome.upToDate);
      expect(fetcher.requests, [base.resolve('manifest.json')]);
      expect(c.read(tablesProvider).value, same(embedded));
    });

    test('أثناء الإعداد الأولي ← لا طلب', () async {
      await prefs.setBool(SettingsRepository.onboardingDoneKey, false);
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      expect(await check(c), UpdateOutcome.notDue);
      expect(fetcher.requests, isEmpty);
    });

    test('محاولتان متزامنتان ← طلب واحد', () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      final n = c.read(dataUpdateProvider.notifier);
      final results = await Future.wait([n.maybeCheck(), n.maybeCheck()]);
      expect(results, [UpdateOutcome.updated, UpdateOutcome.updated]);
      expect(fetcher.requests, hasLength(2)); // البيان والحزمة مرة واحدة.
    });
  });

  group('الحد الأدنى يُسجَّل قبل التثبيت', () {
    test('توقف التطبيق بعد التثبيت مباشرة ← لا تُقبل حزمة أقدم من المثبّتة',
        () async {
      // التثبيت ينجح ثم «يتوقف التطبيق» قبل أي خطوة بعده.
      final crashing = _CrashAfterInstallStore(() async => dir, prefs);
      fetcher.publish(await buildRelease(signer, 3), 3);
      final c = await open(customStore: crashing);
      expect(await check(c), UpdateOutcome.failed);
      // الحد كان قد سُجّل عند لحظة التثبيت.
      expect(crashing.highestSeqAtInstall, 3);
      expect(state().highestSeq, 3);
      expect(await store().read(), isNotNull);

      // الفتح التالي: الحزمة 3 مثبّتة ومستخدمة.
      final c2 = await open();
      expect(c2.read(tablesProvider).value!.meta.dataSeq, 3);

      // حزمة موقّعة أقدم (2) لا تحل محلها.
      fetcher
        ..files.clear()
        ..requests.clear()
        ..publish(await buildRelease(signer, 2), 2);
      now = now.add(const Duration(days: 1));
      expect(await check(c2), UpdateOutcome.upToDate);
      expect(fetcher.requests, [base.resolve('manifest.json')]);
      expect(c2.read(tablesProvider).value!.meta.dataSeq, 3);
      expect(state().highestSeq, 3);
    });

    test('فشل التثبيت ← البيانات الحالية باقية والحد مرفوع (اتجاه الأمان)',
        () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open(customStore: _FailingInstallStore(() async => dir));
      expect(await check(c), UpdateOutcome.failed);
      expect(c.read(tablesProvider).value, same(embedded));
      expect(state().highestSeq, 1);
      expect(state().lastCheckOk, isNull);
    });
  });

  group('مفتاح «تحديث البيانات تلقائياً»', () {
    test('مطفأ ← لا طلب شبكة إطلاقاً من التحقق التلقائي ولا كتابة', () async {
      await prefs.setBool(SettingsRepository.autoUpdateKey, false);
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      expect(await check(c), UpdateOutcome.notDue);
      now = now.add(const Duration(days: 60));
      expect(await check(c), UpdateOutcome.notDue);
      expect(fetcher.requests, isEmpty);
      expect(state().lastAttempt, isNull);
      expect(c.read(tablesProvider).value, same(embedded));
    });

    test('مطفأ ← «تحقق الآن» طلب صريح يعمل (DESIGN 8.7)', () async {
      await prefs.setBool(SettingsRepository.autoUpdateKey, false);
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      expect(
        await c.read(dataUpdateProvider.notifier).checkNow(),
        UpdateOutcome.updated,
      );
      expect(fetcher.requests, hasLength(2));
    });

    test('مفعّل افتراضياً', () async {
      final c = await open();
      expect(c.read(settingsProvider).autoUpdate, isTrue);
      await c.read(settingsProvider.notifier).setAutoUpdate(false);
      expect(prefs.getBool(SettingsRepository.autoUpdateKey), isFalse);
      expect(c.read(settingsProvider).autoUpdate, isFalse);
    });
  });

  group('«تحقق الآن»', () {
    test('يتجاهل مهلة الأسبوع', () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      expect(await check(c), UpdateOutcome.updated);
      fetcher.requests.clear();
      now = now.add(const Duration(minutes: 1));
      final n = c.read(dataUpdateProvider.notifier);
      expect(await n.checkNow(), UpdateOutcome.upToDate);
      expect(fetcher.requests, [base.resolve('manifest.json')]);
      expect(state().lastCheckOk, now);
    });

    test('أثناء تحقق تلقائي جارٍ ← ينتظر نتيجته بلا طلب ثانٍ', () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      final n = c.read(dataUpdateProvider.notifier);
      final auto = n.maybeCheck();
      final manual = n.checkNow();
      expect(await manual, UpdateOutcome.updated);
      expect(await auto, UpdateOutcome.updated);
      expect(fetcher.requests, hasLength(2));
      expect(c.read(dataUpdateProvider).acceptedCount, 1);
    });

    test('نوع الفشل: الشبكة أو التحقق', () async {
      fetcher.failure = FetchFailure.timeout;
      final c = await open();
      final n = c.read(dataUpdateProvider.notifier);
      expect(await n.checkNow(), UpdateOutcome.failed);
      expect(c.read(dataUpdateProvider).failure, UpdateFailure.network);

      fetcher.failure = null;
      final other = await TestSigner.generate();
      fetcher.publish(await buildRelease(other, 1), 1);
      expect(await n.checkNow(), UpdateOutcome.failed);
      expect(c.read(dataUpdateProvider).failure, UpdateFailure.verify);

      fetcher.publish(fixedWasm, 1);
      expect(await n.checkNow(), UpdateOutcome.updated);
      expect(c.read(dataUpdateProvider).failure, isNull);
    });
  });

  test('ساعة الجهاز رجعت للخلف ← لا تحقق في كل عودة، ثم بعد المهلة من الآن',
      () async {
    fetcher.failure = FetchFailure.network;
    final c = await open();
    expect(await check(c), UpdateOutcome.failed);
    expect(fetcher.requests, hasLength(1));

    // رجعت الساعة 3 أيام: الوقت المسجّل صار في المستقبل.
    now = now.subtract(const Duration(days: 3));
    expect(await check(c), UpdateOutcome.notDue);
    expect(await check(c), UpdateOutcome.notDue);
    expect(fetcher.requests, hasLength(1));
    expect(state().lastAttempt, now); // أعيد إلى الآن.

    now = now.add(const Duration(hours: 24));
    expect(await check(c), UpdateOutcome.failed);
    expect(fetcher.requests, hasLength(2));
  });

  group('مصدر البيانات لصفحة المصادر', () {
    test('المضمّنة ← ثم المنزّلة بتاريخ نشرها', () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open();
      expect(await c.read(dataOriginProvider.future), isA<BundledData>());
      await check(c);
      final origin = await c.read(dataOriginProvider.future);
      expect(
        origin,
        isA<DownloadedData>().having(
          (d) => d.publishedAt,
          'publishedAt',
          DateTime(2026, 10, 2),
        ),
      );
    });

    test('تعذّر قراءة المجلد ← غير معروف', () async {
      final c = ProviderContainer(
        overrides: appOverrides(prefs, embedded, [
          updateStoreProvider.overrideWithValue(
            UpdateStore(() async => throw const FileSystemException('x')),
          ),
        ]),
      );
      addTearDown(c.dispose);
      expect(await c.read(dataOriginProvider.future), isA<UnknownDataOrigin>());
    });
  });

  group('معطّل ← لا طلب أبداً', () {
    test('بلا رابط (المثال الفارغ)', () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open(config: const UpdateConfig());
      expect(await check(c), UpdateOutcome.disabled);
      expect(fetcher.requests, isEmpty);
      expect(state().lastAttempt, isNull);
    });

    test('بلا مفتاح موثوق (ثابت الإنتاج الحالي)', () async {
      fetcher.publish(fixedWasm, 1);
      final c = await open(keys: const {});
      expect(await check(c), UpdateOutcome.disabled);
      expect(fetcher.requests, isEmpty);
    });

    test('رابط ليس https أو فيه معاملات', () {
      for (final url in [
        '',
        '   ',
        'http://example.test/durur-data',
        'https://example.test/durur-data?id=1',
        'https://example.test/durur-data#x',
        'https://user@example.test/durur-data',
        'ftp://example.test/',
        'durur-data',
      ]) {
        expect(UpdateConfig(baseUrl: url).isEnabled, isFalse, reason: url);
      }
      for (final url in [
        'https://example.test/durur-data',
        'https://example.test/durur-data/',
      ]) {
        final config = UpdateConfig(baseUrl: url);
        expect(
          config.manifestUri.toString(),
          'https://example.test/durur-data/v1/manifest.json',
        );
        expect(
          config.bundleUri('bundle-3.json').toString(),
          'https://example.test/durur-data/v1/bundle-3.json',
        );
      }
    });

    test('الإعداد الافتراضي في الاختبارات (بلا dart-define) معطّل', () {
      expect(UpdateConfig.fromEnvironment().isEnabled, isFalse);
    });
  });

  group('الرجوع إلى المضمّن (الملاذ الأخير)', () {
    Future<void> installFixed() async {
      fetcher.publish(fixedWasm, 1);
      await check(await open());
      expect(await store().read(), isNotNull);
    }

    test('حزمة تالفة على القرص ← المضمّن وحذفها', () async {
      await installFixed();
      final file = File('${dir.path}/tables/s1/bundle.json');
      await file.writeAsString('{"format":1,"files":{}}');

      final c = await open();
      expect(c.read(tablesProvider).value, same(embedded));
      expect(await store().read(), isNull);
      expect(titles(), isNot(contains(contains(fixedName))));
    });

    test('مؤشر تالف ← المضمّن وحذفه', () async {
      await installFixed();
      await File('${dir.path}/tables/current').writeAsString('x');
      final c = await open();
      expect(c.read(tablesProvider).value, same(embedded));
      expect(await store().read(), isNull);
    });

    test('مضمّن أحدث أو مساوٍ بعد تحديث متجر ← المضمّن وحذف المنزّلة', () async {
      await installFixed();
      final newer = Tables(
        meta: const TablesMeta(
          schemaVersion: 1,
          dataVersion: 'store-1',
          dataSeq: 1,
        ),
        regions: embedded.regions,
        itemList: embedded.itemList,
        regionTables: embedded.regionTables,
        cities: embedded.cities,
        hijri: embedded.hijri,
      );
      final c = await open(embeddedTables: newer);
      expect(c.read(tablesProvider).value, same(newer));
      expect(await store().read(), isNull);
    });

    test('إزالة المفتاح من التطبيق (تسريب) ← المضمّن', () async {
      await installFixed();
      final other = await TestSigner.generate();
      final c = await open(keys: other.trustedKeys);
      expect(c.read(tablesProvider).value, same(embedded));
      expect(await store().read(), isNull);
    });

    test('بلا مجلد دعم (البلجن غير متاح) ← المضمّن بلا خطأ', () async {
      final c = ProviderContainer(
        overrides: appOverrides(prefs, null, [
          embeddedTablesLoaderProvider.overrideWithValue(() async => embedded),
          updateStoreProvider.overrideWithValue(
            UpdateStore(() async => throw const FileSystemException('x')),
          ),
        ]),
      );
      addTearDown(c.dispose);
      expect(await c.read(tablesProvider.future), same(embedded));
    });
  });

  group('المخزن', () {
    test('التثبيت يستبدل السابق ويبقي حزمة واحدة', () async {
      final s = store();
      await s.install(1, [1], [2]);
      await s.install(2, [3], [4]);
      final read = await s.read();
      expect(read!.manifest, [3]);
      expect(read.bundle, [4]);
      final dirs = await Directory('${dir.path}/tables')
          .list()
          .where((e) => e is Directory)
          .map((e) => e.path.split('/').last)
          .toList();
      expect(dirs, ['s2']);
      await s.clear();
      expect(await s.read(), isNull);
    });
  });
}

/// يترك المستمعين والمهام المؤجلة تنتهي.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// يثبّت ثم «يتوقف التطبيق» (استثناء) قبل أي خطوة بعد التثبيت، ويسجّل الحد
/// الأدنى المحفوظ لحظة التثبيت.
class _CrashAfterInstallStore extends UpdateStore {
  _CrashAfterInstallStore(super.baseDir, this._prefs);

  final SharedPreferences _prefs;
  int? highestSeqAtInstall;

  @override
  Future<void> install(int seq, List<int> manifest, List<int> bundle) async {
    highestSeqAtInstall = UpdateState(_prefs).highestSeq;
    await super.install(seq, manifest, bundle);
    throw StateError('توقف التطبيق');
  }
}

/// التثبيت نفسه يفشل (قرص ممتلئ مثلاً).
class _FailingInstallStore extends UpdateStore {
  _FailingInstallStore(super.baseDir);

  @override
  Future<void> install(int seq, List<int> manifest, List<int> bundle) =>
      throw const FileSystemException('قرص ممتلئ');
}
