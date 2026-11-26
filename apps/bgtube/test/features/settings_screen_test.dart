import 'package:bgtube/app.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/data/settings/prefs_locale_store.dart';
import 'package:bgtube/domain/ports/locale_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'player_screen_test.dart' show FakeController;

class MemStore implements LocaleStore {
  MemStore([this.value]);
  String? value;
  bool failing = false;
  @override
  Future<String?> load() async => value;
  @override
  Future<void> save(String code) async {
    if (failing) throw StateError('disk');
    value = code;
  }
}

Future<void> pumpApp(WidgetTester t, MemStore store, {Locale? device}) async {
  t.platformDispatcher.localesTestValue = [device ?? const Locale('ar')];
  addTearDown(t.platformDispatcher.clearLocalesTestValue);
  await t.pumpWidget(ProviderScope(
    overrides: [
      playbackControllerProvider.overrideWithValue(FakeController()),
      localeStoreProvider.overrideWithValue(store),
      initialLanguageCodeProvider.overrideWithValue(store.value),
      appVersionProvider.overrideWithValue('1.2.3'),
    ],
    child: const BgtubeApp(),
  ));
  await t.pumpAndSettle();
}

Future<void> openSettings(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.settings));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Arabic RTL settings screen shows account, language and about', (t) async {
    await pumpApp(t, MemStore());
    await openSettings(t);
    expect(find.text('الإعدادات'), findsWidgets); // العنوان والشريط السفلي
    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('حول'), findsOneWidget);
    expect(find.text('الإصدار 1.2.3'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(Scaffold).first)), TextDirection.rtl);
    expect(find.text('الحساب'), findsOneWidget);
    expect(find.text('غير مسجّل الدخول'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('switching to English applies immediately (LTR) and is saved', (t) async {
    final store = MemStore();
    await pumpApp(t, store);
    await openSettings(t);
    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets); // العنوان والشريط السفلي
    expect(find.text('Language'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(Scaffold).first)), TextDirection.ltr);
    expect(store.value, 'en');
    // الرئيسية بالإنجليزية أيضاً.
    await t.tap(find.byKey(const Key('navHome')));
    await t.pumpAndSettle();
    expect(find.textContaining('Start by searching or pasting a link'), findsOneWidget);
    // وبالعودة للعربية.
    await openSettings(t);
    await t.tap(find.text('العربية'));
    await t.pumpAndSettle();
    expect(find.text('الإعدادات'), findsWidgets); // العنوان والشريط السفلي
    expect(store.value, 'ar');
  });

  testWidgets('saved language wins over the device language on startup', (t) async {
    await pumpApp(t, MemStore('en'), device: const Locale('ar'));
    expect(find.textContaining('Start by searching or pasting a link'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(Scaffold).first)), TextDirection.ltr);
  });

  testWidgets('no saved language: follows the device language (English device)', (t) async {
    await pumpApp(t, MemStore(), device: const Locale('en'));
    expect(find.textContaining('Start by searching or pasting a link'), findsOneWidget);
  });

  testWidgets('no saved language and unsupported device language: Arabic', (t) async {
    await pumpApp(t, MemStore(), device: const Locale('fr'));
    expect(find.textContaining('ابدأ بالبحث أو الصق رابطاً'), findsOneWidget);
    expect(Directionality.of(t.element(find.byType(Scaffold).first)), TextDirection.rtl);
  });

  testWidgets('corrupt saved value is ignored (falls back to device/Arabic)', (t) async {
    await pumpApp(t, MemStore('zz'));
    expect(find.textContaining('ابدأ بالبحث أو الصق رابطاً'), findsOneWidget);
  });

  testWidgets('a storage failure does not stop the language change', (t) async {
    final store = MemStore()..failing = true;
    await pumpApp(t, store);
    await openSettings(t);
    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets); // العنوان والشريط السفلي
    expect(t.takeException(), isNull);
  });

  for (final loc in ['ar', 'en']) {
    testWidgets('settings screen has no overflow at 1.3x font ($loc)', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(t, MemStore(loc));
      await openSettings(t);
      expect(t.takeException(), isNull);
      // أهداف اللمس >= 48dp
      expect(t.getSize(find.byKey(const Key('languageSelector'))).height, greaterThanOrEqualTo(48));
    });
  }

  group('PrefsLocaleStore', () {
    setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

    test('round-trips the language code', () async {
      final s = PrefsLocaleStore(SharedPreferencesAsync());
      expect(await s.load(), isNull);
      await s.save('en');
      expect(await PrefsLocaleStore(SharedPreferencesAsync()).load(), 'en');
    });
  });
}
