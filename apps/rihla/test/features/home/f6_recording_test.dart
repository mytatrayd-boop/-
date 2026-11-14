import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/data/db/app_database.dart';
import 'package:rihla/data/gallery/video_gallery_service.dart';
import 'package:rihla/data/repositories/trip_repository.dart';
import 'package:rihla/features/home/home_controller.dart';
import 'package:rihla/features/home/map_frame_capturer.dart';
import 'package:rihla/l10n/app_localizations_ar.dart';
import 'package:rihla/l10n/app_localizations_en.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

import '../../helpers/fakes.dart';
import 'home_screen_test.dart' show fixAndStart, pumpHome, settleDb;

const _start = ValueKey('start-button');
const _stop = ValueKey('stop-button');

class _FailingStop extends FakeRihlaRecorder {
  @override
  Future<RecordingResult> stop() async {
    recording = false;
    throw const RecorderException('native_error', 'boom');
  }
}

Future<List<TripRow>> trips(WidgetTester t, HomeFakes f) =>
    t.runAsync(() => f.repo.watchTrips().first).then((v) => v!);

Future<void> movePoints(WidgetTester t, HomeFakes f) async {
  // نفس زمن النقطة الأولى (2026-01-01) + 30ث و60ث: سرعة معقولة.
  for (final (i, d) in [0.001, 0.002].indexed) {
    f.location.pushAt(
      24.7 + d,
      46.6 + d,
      time: DateTime.utc(2026, 1, 1, 0, 0, 30 * (i + 1)),
    );
    await t.pump();
    await t.pump();
  }
  await settleDb(t);
}

void main() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();

  testWidgets('عدّ تنازلي 3-2-1: لا تسجيل قبل نهايته وتلغيه لمسة', (t) async {
    final f = HomeFakes();
    final c = await pumpHome(t, f);
    f.location.pushAt(24.7, 46.6);
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(_start));
    await t.pump();
    expect(find.byKey(const ValueKey('countdown-number')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    expect(f.recorder.recording, isFalse);

    await t.tap(find.byKey(const ValueKey('countdown-overlay')));
    await t.pump();
    await t.pump(const Duration(seconds: 5));
    expect(c.read(homeProvider).countdown, isNull);
    expect(c.read(homeProvider).recording, isFalse);
    expect(f.recorder.recording, isFalse);
    expect(await trips(t, f), isEmpty);
  });

  testWidgets('تدفق كامل: بدء، نقاط في DB، تأكيد، إيقاف، ملخص (en)', (t) async {
    final f = HomeFakes();
    final c = await pumpHome(t, f, locale: const Locale('en'));
    c.read(homeProvider.notifier).setQuality(VideoQuality.p1080);
    await fixAndStart(t, f);
    expect(f.recorder.recording, isTrue);
    expect(f.recorder.lastConfig!.quality, RecorderQuality.p1080);
    expect(f.recorder.lastConfig!.muted, isFalse);
    var rows = await trips(t, f);
    expect(rows.single.status, TripStatus.recording);
    expect(rows.single.quality, 1080);

    await movePoints(t, f);
    final id = rows.single.id;
    final pts = await t.runAsync(() => f.repo.getPoints(id));
    expect(pts!.length, 3);
    expect(c.read(homeProvider).distanceM, greaterThan(200));

    // حوار التأكيد: "متابعة" لا توقف.
    await t.tap(find.byKey(_stop));
    await t.pumpAndSettle();
    expect(find.text(en.stopConfirmTitle), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('stop-continue')));
    await t.pumpAndSettle();
    expect(f.recorder.recording, isTrue);
    expect(c.read(homeProvider).recording, isTrue);

    await t.tap(find.byKey(_stop));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('stop-confirm')));
    await settleDb(t);
    await t.pumpAndSettle();
    expect(f.recorder.recording, isFalse);

    // الملخص.
    expect(find.text(en.summarySaved), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-distance')), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-duration')), findsOneWidget);
    expect(find.text(en.summaryGallerySaved), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-new-trip')), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-view-trip')), findsOneWidget);
    rows = await trips(t, f);
    expect(rows.single.status, TripStatus.completed);
    expect(rows.single.videoPath, '/fake/rihla_1.mp4');
    expect(rows.single.distanceM, greaterThan(200));
    expect(c.read(homeProvider).recording, isFalse);
    expect(c.read(homeProvider).finished, isNull);

    await t.tap(find.byKey(const ValueKey('summary-new-trip')));
    await t.pumpAndSettle();
    expect(find.byKey(_start), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('إطارات الخريطة تُدفع للمُسجِّل ~2/ث بعرض نصف اللوحة', (t) async {
    final f = HomeFakes();
    await pumpHome(t, f);
    await fixAndStart(t, f);
    for (var i = 0; i < 4; i++) {
      await t.pump(mapFrameInterval);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pump();
    }
    expect(f.recorder.mapFrames, isNotEmpty);
    final fr = f.recorder.mapFrames.first;
    expect(fr.width, RecorderQuality.p720.mapWidth);
    expect(fr.height, greaterThan(0));
    expect(fr.rgba.length, fr.width * fr.height * 4);
    // لا إطارات بعد الإيقاف.
    final before = f.recorder.mapFrames.length;
    await t.tap(find.byKey(_stop));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('stop-confirm')));
    await settleDb(t);
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    expect(f.recorder.mapFrames.length, before);
  });

  testWidgets('انقطاع من المُسجِّل: يحفظ ما صُوِّر ويبلغ المستخدم', (t) async {
    final f = HomeFakes();
    final c = await pumpHome(t, f);
    await fixAndStart(t, f);
    await movePoints(t, f);
    // الحوار مفتوح لحظة الانقطاع: يُغلق ويُنقل للملخص.
    await t.tap(find.byKey(_stop));
    await t.pumpAndSettle();
    f.recorder.emitInterruption(InterruptReason.background);
    await settleDb(t);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('stop-dialog')), findsNothing);
    expect(find.text(ar.summaryInterruptedBackground), findsOneWidget);
    final rows = await trips(t, f);
    expect(rows.single.status, TripStatus.interrupted);
    expect(rows.single.videoPath, '/fake/rihla_1.mp4');
    expect((await t.runAsync(() => f.repo.getPoints(rows.single.id)))!.length, 3);
    expect(c.read(homeProvider).recording, isFalse);
    expect(f.awake.enabled, isFalse);
  });

  testWidgets('فشل بدء المُسجِّل: رسالة ولا رحلة في DB', (t) async {
    final f = HomeFakes();
    final c = await pumpHome(t, f);
    f.recorder.cameraOpen = false; // start يرمي camera_not_open
    await fixAndStart(t, f);
    await t.pump();
    expect(c.read(homeProvider).recording, isFalse);
    expect(find.text(ar.startFailed), findsOneWidget);
    expect(await trips(t, f), isEmpty);
    expect(find.byKey(_start), findsOneWidget);
  });

  testWidgets('فشل stop: المسار محفوظ ورسالة تعذّر حفظ الفيديو', (t) async {
    final f = HomeFakes(recorder: _FailingStop()..cameraOpen = true);
    await pumpHome(t, f);
    await fixAndStart(t, f);
    await movePoints(t, f);
    await t.tap(find.byKey(_stop));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('stop-confirm')));
    await settleDb(t);
    await t.pumpAndSettle();
    expect(find.text(ar.summaryVideoFailed), findsOneWidget);
    final rows = await trips(t, f);
    expect(rows.single.status, TripStatus.interrupted);
    expect(rows.single.videoPath, isNull);
    expect((await t.runAsync(() => f.repo.getPoints(rows.single.id)))!.length, 3);
  });

  f6FixTests();
  f8GalleryTests();

  testWidgets('كتم أثناء التسجيل يصل للمُسجِّل', (t) async {
    final f = HomeFakes();
    await pumpHome(t, f);
    await fixAndStart(t, f);
    await t.tap(find.byKey(const ValueKey('mute-button')));
    await t.pump();
    expect(f.recorder.muted, isTrue);
  });
}

/// start يتأخر حتى نحرره، ليُلمس الإلغاء أثناء الـawait.
class _SlowStart extends FakeRihlaRecorder {
  final gate = Completer<void>();
  int stopCalls = 0;
  @override
  Future<bool> start(RecordingConfig config) async {
    final r = await super.start(config);
    await gate.future;
    return r;
  }

  @override
  Future<RecordingResult> stop() {
    stopCalls++;
    return super.stop();
  }
}

class _ThrowingStart extends FakeRihlaRecorder {
  @override
  Future<bool> start(RecordingConfig config) async => throw StateError('plugin');
}

class _FailingCompleteRepo extends TripRepository {
  _FailingCompleteRepo(super.db, {this.failInterruptToo = false});
  final bool failInterruptToo;
  @override
  Future<void> completeTrip(String tripId,
          {DateTime? endedAt, String? videoAssetId, String? videoPath}) =>
      throw StateError('db');
  @override
  Future<void> interruptTrip(String tripId, {DateTime? endedAt, String? videoPath}) =>
      failInterruptToo
          ? throw StateError('db2')
          : super.interruptTrip(tripId, endedAt: endedAt, videoPath: videoPath);
}

Future<void> confirmStop(WidgetTester t) async {
  await t.tap(find.byKey(_stop));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('stop-confirm')));
  await settleDb(t);
  await t.pumpAndSettle();
}

void f6FixTests() {
  final ar = AppLocalizationsAr();

  testWidgets('إلغاء العدّ أثناء await recorder.start يوقف المُسجِّل ولا رحلة', (t) async {
    final rec = _SlowStart()..cameraOpen = true;
    final f = HomeFakes(recorder: rec);
    final c = await pumpHome(t, f);
    f.location.pushAt(24.7, 46.6);
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(_start));
    await t.pump();
    await t.pump(const Duration(seconds: 3)); // _begin عالق في start
    expect(rec.recording, isTrue);
    await t.tap(find.byKey(const ValueKey('countdown-overlay')));
    await t.pump();
    rec.gate.complete();
    await settleDb(t);
    expect(rec.recording, isFalse);
    expect(rec.stopCalls, 1);
    expect(c.read(homeProvider).recording, isFalse);
    expect(c.read(homeProvider).countdown, isNull);
    expect(await trips(t, f), isEmpty);
  });

  testWidgets('dispose بعد نجاح start يوقف المُسجِّل', (t) async {
    final rec = _SlowStart()..cameraOpen = true;
    final f = HomeFakes(recorder: rec);
    await pumpHome(t, f);
    f.location.pushAt(24.7, 46.6);
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(_start));
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    expect(rec.recording, isTrue);
    await t.pumpWidget(const SizedBox()); // يُفكّ ProviderScope
    rec.gate.complete();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    expect(rec.recording, isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('استثناء غير RecorderException من start: رسالة فشل لا انهيار', (t) async {
    final f = HomeFakes(recorder: _ThrowingStart()..cameraOpen = true);
    final c = await pumpHome(t, f);
    await fixAndStart(t, f);
    await t.pump();
    expect(c.read(homeProvider).recording, isFalse);
    expect(c.read(homeProvider).countdown, isNull);
    expect(find.text(ar.startFailed), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('فشل completeTrip: لا saving عالق، ملخص بفيديو محفوظ المسار', (t) async {
    final f = HomeFakes(repoBuilder: (db) => _FailingCompleteRepo(db));
    final c = await pumpHome(t, f);
    await fixAndStart(t, f);
    await movePoints(t, f);
    await confirmStop(t);
    expect(c.read(homeProvider).saving, isFalse);
    expect(find.text(ar.summarySaved), findsOneWidget);
    expect(find.text(ar.summaryDbError), findsOneWidget);
    final rows = await trips(t, f);
    expect(rows.single.status, TripStatus.interrupted);
    expect(rows.single.videoPath, '/fake/rihla_1.mp4');
    expect(t.takeException(), isNull);
  });

  testWidgets('فشل completeTrip وinterruptTrip معاً: ينتقل للملخص برسالة خطأ', (t) async {
    final f = HomeFakes(
      repoBuilder: (db) => _FailingCompleteRepo(db, failInterruptToo: true),
    );
    final c = await pumpHome(t, f);
    await fixAndStart(t, f);
    await confirmStop(t);
    expect(c.read(homeProvider).saving, isFalse);
    expect(c.read(homeProvider).recording, isFalse);
    expect(find.text(ar.summaryDbError), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

void f8GalleryTests() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();

  testWidgets('حفظ في الألبوم: تم، ويُخزَّن videoAssetId (en)', (t) async {
    final f = HomeFakes();
    await pumpHome(t, f, locale: const Locale('en'));
    await fixAndStart(t, f);
    await confirmStop(t);
    expect(find.text(en.summaryGallerySaved), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-gallery-retry')), findsNothing);
    expect(f.gallery.saved, ['/fake/rihla_1.mp4']);
    final rows = await trips(t, f);
    expect(rows.single.videoAssetId, 'fake-asset-1');
  });

  testWidgets('فشل الحفظ ثم إعادة المحاولة تنجح (ar)', (t) async {
    final f = HomeFakes(gallery: FakeVideoGalleryService(failures: 1));
    await pumpHome(t, f);
    await fixAndStart(t, f);
    await confirmStop(t);
    expect(find.text(ar.summaryGalleryFailed), findsOneWidget);
    expect(find.text(ar.summaryGalleryRetry), findsOneWidget);
    expect((await trips(t, f)).single.videoAssetId, isNull);
    await t.tap(find.byKey(const ValueKey('summary-gallery-retry')));
    await settleDb(t);
    await t.pumpAndSettle();
    expect(find.text(ar.summaryGallerySaved), findsOneWidget);
    expect(f.gallery.calls, 2);
    expect((await trips(t, f)).single.videoAssetId, 'fake-asset-1');
  });

  testWidgets('حالة "جاري الحفظ" تظهر أثناء الحفظ', (t) async {
    final f = HomeFakes(gallery: _SlowGallery());
    await pumpHome(t, f);
    await fixAndStart(t, f);
    await t.tap(find.byKey(_stop));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('stop-confirm')));
    await settleDb(t);
    await t.pump();
    expect(find.text(ar.summaryGallerySaving), findsOneWidget);
    (f.gallery as _SlowGallery).gate.complete();
    await settleDb(t);
    expect(find.text(ar.summaryGallerySaved), findsOneWidget);
  });

  testWidgets('فشل stop (بلا فيديو): لا محاولة حفظ في الألبوم', (t) async {
    final f = HomeFakes(recorder: _FailingStop()..cameraOpen = true);
    await pumpHome(t, f);
    await fixAndStart(t, f);
    await confirmStop(t);
    expect(find.text(ar.summaryVideoFailed), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-gallery')), findsNothing);
    expect(f.gallery.calls, 0);
  });
}

class _SlowGallery extends FakeVideoGalleryService {
  final gate = Completer<void>();
  @override
  Future<String?> saveVideo(String path) async {
    await gate.future;
    return super.saveVideo(path);
  }
}
