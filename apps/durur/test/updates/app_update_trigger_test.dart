import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/updates/data_updater.dart';
import 'package:durur/src/updates/update_config.dart';
import 'package:durur/src/updates/update_fetcher.dart';
import 'package:durur/src/updates/update_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import 'update_test_kit.dart';

/// التطبيق يتحقق بعد رسم أول إطار وعند العودة للواجهة فقط، حسب الموعد
/// (ARCHITECTURE §16.2)، ولا يظهر للمستخدم أي خطأ شبكة.
void main() {
  late Tables tables;
  late TestSigner signer;

  setUpAll(() async {
    tables = await loadAssetTables();
    signer = await TestSigner.generate();
  });

  testWidgets('بعد أول إطار محاولة واحدة، والعودة قبل 24 ساعة لا تكرر', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 2, 10);
    final fetcher = FakeFetcher()..failure = FetchFailure.network;
    final prefs = await fakePrefs(savedCity('riyadh'));
    await pumpDururApp(
      tester,
      prefs: prefs,
      tables: tables,
      extra: [
        embeddedTablesLoaderProvider.overrideWithValue(() async => tables),
        updateFetcherProvider.overrideWithValue(fetcher),
        trustedKeysProvider.overrideWithValue(signer.trustedKeys),
        updateConfigProvider.overrideWithValue(
          const UpdateConfig(baseUrl: 'https://example.test/durur-data'),
        ),
        appBuildProvider.overrideWith((ref) async => 1),
        clockProvider.overrideWith((ref) => () => now),
      ],
    );
    expect(fetcher.requests, hasLength(1));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Directionality).first),
    );
    expect(container.read(dataUpdateProvider).outcome, UpdateOutcome.failed);
    expect(tester.takeException(), isNull);

    Future<void> resume() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    now = now.add(const Duration(hours: 2));
    await resume();
    expect(fetcher.requests, hasLength(1));

    now = now.add(const Duration(hours: 22));
    await resume();
    expect(fetcher.requests, hasLength(2));
    expect(
      UpdateState(prefs).lastAttempt,
      now,
    );
  });

  testWidgets('بلا إعداد (البناء الافتراضي) لا طلب ولا كتابة', (tester) async {
    final fetcher = FakeFetcher();
    final prefs = await fakePrefs(savedCity('riyadh'));
    await pumpDururApp(
      tester,
      prefs: prefs,
      tables: tables,
      extra: [updateFetcherProvider.overrideWithValue(fetcher)],
    );
    expect(fetcher.requests, isEmpty);
    expect(UpdateState(prefs).lastAttempt, isNull);
  });
}
