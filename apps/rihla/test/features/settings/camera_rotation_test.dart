import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/data/camera/camera_preview_source.dart';
import 'package:rihla/data/camera/fake_camera_preview_source.dart';
import 'package:rihla/data/platform/screen_orientation.dart';
import 'package:rihla/data/settings/camera_rotation_store.dart';
import 'package:rihla/features/home/home_controller.dart';
import 'package:rihla/features/settings/camera_rotation_controller.dart';
import 'package:rihla/features/settings/settings_screen.dart';
import 'package:rihla/l10n/app_localizations.dart';
import 'package:rihla_recorder/rihla_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> pumpSettings(
  WidgetTester t, {
  required FakeRihlaRecorder rec,
  required MemoryCameraRotationStore store,
  Locale locale = const Locale('ar'),
  FakeCameraPreviewSource? camera,
}) async {
  final c = ProviderContainer(
    overrides: [
      recorderProvider.overrideWithValue(rec),
      cameraRotationStoreProvider.overrideWithValue(store),
      cameraPreviewSourceProvider.overrideWithValue(camera ?? FakeCameraPreviewSource()),
      screenOrientationProvider.overrideWithValue(FakeScreenOrientation()),
    ],
  );
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: const SettingsScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

void main() {
  group('المخزن', () {
    test('الافتراضي 270 وقيم غير صالحة ترجع له', () {
      expect(defaultCameraRotation, 270);
      expect(sanitizeCameraRotation(null), 270);
      expect(sanitizeCameraRotation(45), 270);
      for (final d in cameraRotationChoices) {
        expect(sanitizeCameraRotation(d), d);
      }
    });

    test('shared_preferences: يحفظ ويقرأ', () async {
      SharedPreferences.setMockInitialValues({});
      const s = SharedPrefsCameraRotationStore();
      expect(await s.load(), 270);
      await s.save(90);
      expect(await s.load(), 90);
      SharedPreferences.setMockInitialValues({SharedPrefsCameraRotationStore.key: 33});
      expect(await s.load(), 270);
    });
  });

  group('القناة', () {
    final calls = <MethodCall>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('rihla_recorder'),
        (c) async {
          calls.add(c);
          if (c.method == 'getOrientationInfo') {
            return {
              'sensorRotation': 90,
              'displayRotation': 90,
              'rotationDegrees': 0,
              'computedRotation': 0,
              'offset': 270,
              'finalRotation': 270,
              'cameraOpen': true,
            };
          }
          if (c.method == 'start') return {'micAvailable': true};
          return null;
        },
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('rihla_recorder'),
        null,
      );
    });

    TestWidgetsFlutterBinding.ensureInitialized();

    test('setRotationOffset وgetOrientationInfo وstart تمرّر الإزاحة', () async {
      final r = MethodChannelRihlaRecorder();
      await r.setRotationOffset(180);
      expect(calls.last.method, 'setRotationOffset');
      expect(calls.last.arguments, {'degrees': 180});
      final i = await r.getOrientationInfo();
      expect(i.sensorRotation, 90);
      expect(i.displayRotation, 90);
      expect(i.rotationDegrees, 0);
      expect(i.computedRotation, 0);
      expect(i.offset, 270);
      expect(i.finalRotation, 270);
      expect(i.cameraOpen, isTrue);
      expect(i.toText(), contains('sensorRotation=90'));
      await r.start(const RecordingConfig(rotationOffset: 90));
      expect((calls.last.arguments as Map)['rotationOffset'], 90);
      await r.start(const RecordingConfig());
      expect((calls.last.arguments as Map).containsKey('rotationOffset'), isFalse);
    });

    test('حدث previewSize يُحلَّل', () {
      final e = MethodChannelRihlaRecorder.parseEvent({'type': 'previewSize', 'width': 720, 'height': 1280});
      expect(e, isA<PreviewSizeChanged>());
      expect((e! as PreviewSizeChanged).height, 1280);
    });
  });

  test('المصدر الأصلي يمرّر الإزاحة المحفوظة قبل فتح الكاميرا ويتبع previewSize', () async {
    final rec = FakeRihlaRecorder();
    final src = NativeCameraPreviewSource(rec, rotationStore: MemoryCameraRotationStore(180));
    await src.open();
    expect(rec.rotationOffsetCalls, [180]);
    expect(rec.cameraOpen, isTrue);
    await src.close();
  });

  for (final loc in ['ar', 'en']) {
    testWidgets('الإعدادات: اختيار الزاوية يحفظ ويُطبَّق ($loc)', (t) async {
      final rec = FakeRihlaRecorder();
      final store = MemoryCameraRotationStore();
      final c = await pumpSettings(t, rec: rec, store: store, locale: Locale(loc));
      final s = lookupAppLocalizations(Locale(loc));
      expect(find.text(s.settingsCameraRotation), findsOneWidget);
      expect(find.text(s.cameraDiagTitle), findsOneWidget);
      // الافتراضي 270 محدد.
      expect(t.widget<ChoiceChip>(find.byKey(const ValueKey('rotation-270'))).selected, isTrue);
      await t.ensureVisible(find.byKey(const ValueKey('rotation-90')));
      await t.tap(find.byKey(const ValueKey('rotation-90')));
      await t.pumpAndSettle();
      expect(c.read(cameraRotationProvider), 90);
      expect(store.value, 90);
      expect(rec.rotationOffsetCalls, [90]);
      expect(t.widget<ChoiceChip>(find.byKey(const ValueKey('rotation-90'))).selected, isTrue);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('يحمّل القيمة المحفوظة عند الفتح', (t) async {
    final c = await pumpSettings(t, rec: FakeRihlaRecorder(), store: MemoryCameraRotationStore(0));
    expect(c.read(cameraRotationProvider), 0);
    expect(t.widget<ChoiceChip>(find.byKey(const ValueKey('rotation-0'))).selected, isTrue);
  });

  testWidgets('التشخيص يعرض القيم بعد التحديث', (t) async {
    final rec = FakeRihlaRecorder();
    await pumpSettings(t, rec: rec, store: MemoryCameraRotationStore());
    final s = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(s.cameraDiagUnavailable), findsWidgets);
    await t.ensureVisible(find.byKey(const ValueKey('diag-refresh')));
    await t.tap(find.byKey(const ValueKey('diag-refresh')));
    await t.pumpAndSettle();
    expect(find.text(s.cameraDiagUnavailable), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('diag-table')), matching: find.text('90°')), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('زر الاختبار يفتح معاينة حية ويغلق الكاميرا عند الرجوع', (t) async {
    final rec = FakeRihlaRecorder();
    final cam = FakeCameraPreviewSource();
    await pumpSettings(t, rec: rec, store: MemoryCameraRotationStore(), camera: cam);
    await t.ensureVisible(find.byKey(const ValueKey('camera-test-button')));
    await t.tap(find.byKey(const ValueKey('camera-test-button')));
    await t.pumpAndSettle();
    expect(cam.isOpen, isTrue);
    expect(find.byKey(FakeCameraPreviewSource.previewKey), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rotation-180')));
    await t.pumpAndSettle();
    expect(rec.rotationOffsetCalls, [180]);
    await t.tap(find.byKey(const ValueKey('camera-test-done')));
    await t.pumpAndSettle();
    expect(cam.isOpen, isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('خروج مبكر أثناء open: تُغلق الكاميرا بعد اكتماله', (t) async {
    final rec = FakeRihlaRecorder();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1600, 2400);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final cam = _SlowCamera();
    await pumpSettings(t, rec: rec, store: MemoryCameraRotationStore(), camera: cam);
    await t.ensureVisible(find.byKey(const ValueKey('camera-test-button')));
    await t.tap(find.byKey(const ValueKey('camera-test-button')));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(cam.openCalls, 1);
    await t.tap(find.byKey(const ValueKey('camera-test-done')));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('camera-test-done')), findsNothing);
    cam.gate.complete();
    await t.pumpAndSettle();
    expect(cam.isOpen, isFalse);
    expect(cam.closeCalls, greaterThan(0));
    expect(t.takeException(), isNull);
  });

  test('ARB: نصوص الإعداد والتشخيص بالعربية والإنجليزية بالمفاتيح نفسها', () {
    Map<String, dynamic> load(String l) =>
        jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync()) as Map<String, dynamic>;
    final ar = load('ar');
    final en = load('en');
    const keys = [
      'settingsCameraRotation', 'settingsCameraRotationHint', 'rotationDegreesLabel', 'cameraRotationTest',
      'cameraRotationTestHint', 'cameraRotationDone', 'cameraRotationOpenFailed', 'cameraDiagTitle',
      'cameraDiagHint', 'cameraDiagSensor', 'cameraDiagDisplay', 'cameraDiagCameraX', 'cameraDiagComputed',
      'cameraDiagOffset', 'cameraDiagFinal', 'cameraDiagUnavailable', 'cameraDiagRefresh', 'cameraDiagCopy',
      'cameraDiagCopied',
    ];
    for (final k in keys) {
      expect((ar[k] as String?)?.isNotEmpty, isTrue, reason: 'ar $k');
      expect((en[k] as String?)?.isNotEmpty, isTrue, reason: 'en $k');
    }
    expect(ar['settingsCameraRotation'], isNot(en['settingsCameraRotation']));
    expect(ar['cameraDiagTitle'], isNot(en['cameraDiagTitle']));
  });
}

class _SlowCamera extends FakeCameraPreviewSource {
  final gate = Completer<void>();
  @override
  Future<void> open() async {
    openCalls++;
    await gate.future;
    isOpen = true;
  }
}
