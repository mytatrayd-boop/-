import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rihla/app.dart';
import 'package:rihla/core/locale/locale_provider.dart';
import 'package:rihla/data/camera/fake_camera_preview_source.dart';
import 'package:rihla/data/map/map_tiles.dart';
import 'package:rihla/data/permissions/fake_permission_service.dart';
import 'package:rihla/data/permissions/permission_service.dart';
import 'package:rihla/features/home/home_controller.dart';
import 'package:rihla/features/home/home_screen.dart';
import 'package:rihla/features/home/widgets/recording_map.dart';
import 'package:rihla/l10n/app_localizations.dart';
import 'package:rihla/l10n/app_localizations_ar.dart';
import 'package:rihla/l10n/app_localizations_en.dart';

import '../../helpers/fakes.dart';

final ar = AppLocalizationsAr();
final en = AppLocalizationsEn();

const _start = ValueKey('start-button');
const _stop = ValueKey('stop-button');

class _Fixed extends LocaleNotifier {
  _Fixed(this.l);
  final Locale l;
  @override
  Locale? build() => l;
}

Future<ProviderContainer> pumpHome(
  WidgetTester t,
  HomeFakes f, {
  Locale locale = const Locale('ar'),
  Size size = const Size(800, 360),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...f.overrides,
        localeProvider.overrideWith(() => _Fixed(locale)),
      ],
      child: const RihlaApp(),
    ),
  );
  await t.pumpAndSettle();
  return ProviderScope.containerOf(t.element(find.byType(HomeScreen)));
}

Future<void> fixAndStart(WidgetTester t, HomeFakes f) async {
  f.location.pushAt(24.7, 46.6);
  await t.pump(); // يُسلَّم الحدث
  await t.pump(); // يُعاد البناء
  await t.tap(find.byKey(_start));
  await t.pump();
  // العدّ التنازلي 3-2-1 ثم البدء.
  await t.pump(const Duration(seconds: 3));
  await t.pump();
  await t.pump();
}

void main() {
  for (final loc in ['ar', 'en']) {
    testWidgets('تقسيم 50/50 ثابت: خريطة يسار وكاميرا يمين ($loc)', (t) async {
      await pumpHome(t, HomeFakes(), locale: Locale(loc));
      final map = t.getRect(find.byType(RecordingMap));
      final cam = t.getRect(find.byKey(FakeCameraPreviewSource.previewKey));
      expect(map.left, 0);
      expect(map.width, 400);
      expect(cam.width, 400);
      expect(map.right, cam.left);
      expect(cam.right, 800);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('الإسناد ظاهر داخل RepaintBoundary وغير مقصوص ولا مغطّى', (
    t,
  ) async {
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 360,
          child: RecordingMap(
            boundaryKey: key,
            tiles: const FakeMapTiles(),
            fix: null,
            track: const [],
            interactive: true,
          ),
        ),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
      ),
    );
    await t.pump();
    expect(
      key.currentContext!.findRenderObject(),
      isA<RenderRepaintBoundary>(),
    );
    for (final line in [mapAttributionLine1, mapAttributionLine2]) {
      expect(
        find.descendant(of: find.byKey(key), matching: find.text(line)),
        findsOneWidget,
      );
    }
    final box = t.getRect(find.byKey(const ValueKey('map-attribution')));
    final mapRect = t.getRect(find.byKey(key));
    expect(mapRect.contains(box.topLeft), isTrue);
    expect(mapRect.contains(box.bottomRight - const Offset(1, 1)), isTrue);
    expect(box.right, mapRect.right);
    expect(box.bottom, mapRect.bottom);
  });

  testWidgets('لا بدء بدون موقع: الزر لا يفعل شيئاً ويظهر السبب', (t) async {
    final f = HomeFakes();
    final c = await pumpHome(t, f);
    expect(f.camera.isOpen, isTrue);
    expect(find.text(ar.mapLocating), findsWidgets);
    await t.tap(find.byKey(_start));
    await t.pump();
    expect(c.read(homeProvider).recording, isFalse);
    expect(f.awake.enabled, isFalse);
    expect(find.byKey(_stop), findsNothing);
  });

  testWidgets('لا بدء بدون إذن الكاميرا أو الموقع ولا اشتراك GPS', (t) async {
    final f = HomeFakes(
      permissions: FakePermissionService(
        initial: {
          AppPermission.camera: AppPermissionStatus.denied,
          AppPermission.location: AppPermissionStatus.granted,
        },
      ),
    );
    final c = await pumpHome(t, f);
    expect(find.text(ar.permStartBlocked), findsOneWidget);
    expect(find.byKey(const ValueKey('open-permissions')), findsOneWidget);
    expect(f.camera.openCalls, 0);
    f.location.pushAt(24.7, 46.6);
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(_start));
    await t.pump();
    expect(c.read(homeProvider).recording, isFalse);
  });

  testWidgets('موقع تقريبي فقط يمنع البدء ولا اشتراك GPS', (t) async {
    final f = HomeFakes(
      permissions: FakePermissionService(
        initial: {
          AppPermission.camera: AppPermissionStatus.granted,
          AppPermission.location: AppPermissionStatus.approximateOnly,
        },
      ),
    );
    final c = await pumpHome(t, f);
    expect(f.location.listeners, 0);
    expect(find.text(ar.permStartBlocked), findsOneWidget);
    expect(c.read(homeProvider.notifier).canStart, isFalse);
  });

  testWidgets('تعذّر فتح الكاميرا: رسالة وإعادة محاولة تنجح', (t) async {
    final f = HomeFakes(camera: FakeCameraPreviewSource(failTimes: 1));
    final c = await pumpHome(t, f, locale: const Locale('en'));
    expect(find.text(en.cameraError), findsOneWidget);
    f.location.pushAt(24.7, 46.6);
    await t.pump();
    await t.pump();
    expect(c.read(homeProvider.notifier).canStart, isFalse);
    await t.tap(find.byKey(const ValueKey('camera-retry')));
    await t.pumpAndSettle();
    expect(find.text(en.cameraError), findsNothing);
    expect(c.read(homeProvider.notifier).canStart, isTrue);
  });

  testWidgets('بدء وإيقاف: مؤقت ومسار حي ومسافة وشاشة مضاءة', (t) async {
    final f = HomeFakes();
    final c = await pumpHome(t, f);
    await fixAndStart(t, f);
    expect(c.read(homeProvider).recording, isTrue);
    expect(f.awake.enabled, isTrue);
    expect(find.byKey(_stop), findsOneWidget);
    expect(find.byKey(const ValueKey('open-settings')), findsNothing);
    expect(find.byType(PolylineLayer), findsNothing);

    f.location.pushAt(24.701, 46.601);
    await t.pump();
    await t.pump();
    f.location.pushAt(24.702, 46.602);
    await t.pump();
    await t.pump();
    expect(c.read(homeProvider).track.length, 3);
    expect(c.read(homeProvider).distanceM, greaterThan(200));
    expect(find.byType(PolylineLayer), findsOneWidget);

    await t.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('rec-timer')), findsOneWidget);
    expect(c.read(homeProvider).elapsed.inSeconds, greaterThanOrEqualTo(2));

    // نقطة بدقة سيئة لا تدخل المسار لكن يُحدَّث الموقع.
    f.location.pushAt(24.9, 46.9, accuracy: 120);
    await t.pump();
    await t.pump();
    expect(c.read(homeProvider).track.length, 3);

    await t.tap(find.byKey(_stop));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('stop-confirm')));
    await t.pumpAndSettle();
    expect(c.read(homeProvider).recording, isFalse);
    expect(f.awake.enabled, isFalse);
    expect(find.byKey(const ValueKey('summary-new-trip')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('كتم وجودة: الجودة تتعطل أثناء التسجيل', (t) async {
    final f = HomeFakes();
    final c = await pumpHome(t, f);
    await t.tap(find.byKey(const ValueKey('mute-button')));
    await t.pump();
    expect(c.read(homeProvider).muted, isTrue);
    expect(find.text(ar.audioMuted), findsOneWidget);
    expect(find.byKey(const ValueKey('hud-muted')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('quality-button')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('quality-p1080')));
    await t.pumpAndSettle();
    expect(c.read(homeProvider).quality, VideoQuality.p1080);
    expect(find.text('1080p'), findsOneWidget);

    await fixAndStart(t, f);
    await t.tap(find.byKey(const ValueKey('quality-button')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('quality-p720')), findsNothing);
    c.read(homeProvider.notifier).setQuality(VideoQuality.p720);
    expect(c.read(homeProvider).quality, VideoQuality.p1080);
  });

  testWidgets('إشارة GPS ضعيفة: شريحة تنبيه ويمكن البدء', (t) async {
    final f = HomeFakes();
    final c = await pumpHome(t, f);
    f.location.pushAt(24.7, 46.6, accuracy: 80);
    await t.pump();
    await t.pump();
    expect(find.text(ar.gpsWeak), findsOneWidget);
    expect(c.read(homeProvider.notifier).canStart, isTrue);
  });

  testWidgets('انقطاع الإنترنت: رسالة تظهر وتختفي', (t) async {
    final f = HomeFakes();
    await pumpHome(t, f);
    expect(find.byKey(const ValueKey('offline-banner')), findsNothing);
    f.network.set(false);
    await t.pump();
    await t.pump();
    expect(find.text(ar.offlineBanner), findsOneWidget);
    f.network.set(true);
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('offline-banner')), findsNothing);
  });

  testWidgets('أحجام الأزرار حسب DESIGN: 88 و64', (t) async {
    await pumpHome(t, HomeFakes());
    expect(t.getSize(find.byKey(_start)), const Size(88, 88));
    expect(
      t.getSize(find.byKey(const ValueKey('mute-button'))),
      const Size(64, 64),
    );
    expect(
      t.getSize(find.byKey(const ValueKey('quality-button'))),
      const Size(64, 64),
    );
  });

  for (final loc in ['ar', 'en']) {
    testWidgets('بلا overflow على 640x300 بخط 130% أثناء التسجيل ($loc)', (
      t,
    ) async {
      final f = HomeFakes();
      t.view.physicalSize = const Size(640, 300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            ...f.overrides,
            localeProvider.overrideWith(() => _Fixed(Locale(loc))),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(640, 300),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const RihlaApp(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await fixAndStart(t, f);
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    });
  }
}
