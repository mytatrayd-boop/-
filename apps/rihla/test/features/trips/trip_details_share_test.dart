import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show OutlinedButton;
import 'package:rihla/core/router/app_router.dart';
import 'package:rihla/data/share/share_service.dart';
import 'package:rihla/l10n/app_localizations_ar.dart';
import 'package:rihla/l10n/app_localizations_en.dart';
import 'package:xml/xml.dart';

import '../../helpers/fakes.dart';
import '../../helpers/trips_helper.dart';

const _video = '/fake/trip.mp4';

Future<(HomeFakes, String)> open(
  WidgetTester t, {
  bool videoOnDisk = true,
  bool withVideo = true,
  Locale locale = const Locale('ar'),
  FakeShareService? share,
}) async {
  final f = HomeFakes(
    share: share ?? FakeShareService(existing: videoOnDisk ? {_video} : {}),
  );
  final id = await seedTrip(t, f.repo, videoPath: withVideo ? _video : null);
  await pumpApp(t, f, initial: AppRoutes.tripFor(id), locale: locale);
  await settle(t);
  return (f, id);
}

void main() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();

  for (final loc in ['ar', 'en']) {
    final s = loc == 'ar' ? ar : en;
    testWidgets(
      'تفاصيل الرحلة: خريطة بالمسار والمدة والمسافة والتاريخ ($loc)',
      (t) async {
        await open(t, locale: Locale(loc));
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(PolylineLayer), findsOneWidget);
        expect(find.byKey(const ValueKey('trip-duration')), findsOneWidget);
        expect(find.text('${s.summaryDuration}: 02:30'), findsOneWidget);
        expect(find.byKey(const ValueKey('trip-distance')), findsOneWidget);
        expect(find.byKey(const ValueKey('trip-date')), findsOneWidget);
        expect(find.text(s.tripPlayVideo), findsOneWidget);
        expect(find.text(s.tripShare), findsOneWidget);
        expect(find.text(s.tripDelete), findsOneWidget);
        expect(t.takeException(), isNull);
        await disposeApp(t);
      },
    );
  }

  testWidgets('تشغيل الفيديو يفتحه في مشغل النظام', (t) async {
    final (f, _) = await open(t);
    await t.tap(find.byKey(const ValueKey('trip-play')));
    await t.pumpAndSettle();
    expect(f.share.openedFiles, [_video]);
    await disposeApp(t);
  });

  testWidgets('فشل فتح الفيديو: رسالة', (t) async {
    final share = FakeShareService(existing: {_video})..openFileResult = false;
    await open(t, share: share);
    await t.tap(find.byKey(const ValueKey('trip-play')));
    await t.pumpAndSettle();
    expect(find.text(ar.tripPlayFailed), findsOneWidget);
    await disposeApp(t);
  });

  testWidgets('الفيديو مفقود: لا زر تشغيل وتظهر الرسالة', (t) async {
    await open(t, videoOnDisk: false);
    expect(find.byKey(const ValueKey('trip-play')), findsNothing);
    expect(find.byKey(const ValueKey('trip-video-missing')), findsOneWidget);
    await disposeApp(t);
  });

  testWidgets('رحلة بلا نقاط: تفاصيلها تعرض «لا مسار» بلا انهيار', (t) async {
    final f = HomeFakes();
    final id = await seedTrip(t, f.repo, points: 0);
    await pumpApp(t, f, initial: AppRoutes.tripFor(id));
    await settle(t);
    expect(find.byKey(const ValueKey('trip-no-route')), findsOneWidget);
    expect(find.text(ar.tripNoRoute), findsOneWidget);
    expect(ar.tripNoRoute, 'لا مسار (إشارة GPS ضعيفة)');
    expect(t.takeException(), isNull);
    await disposeApp(t);
  });

  testWidgets('حذف: إلغاء يُبقي الرحلة، وتأكيد يحذفها ويعود لـ«رحلاتي»', (
    t,
  ) async {
    final (f, id) = await open(t);
    await t.tap(find.byKey(const ValueKey('trip-delete')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-dialog')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('delete-cancel')));
    await t.pumpAndSettle();
    expect((await t.runAsync(() => f.repo.getTrip(id))), isNotNull);

    await t.tap(find.byKey(const ValueKey('trip-delete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('delete-confirm')));
    await settle(t);
    expect((await t.runAsync(() => f.repo.getTrip(id))), isNull);
    expect((await t.runAsync(() => f.repo.getPoints(id))), isEmpty);
    expect(find.text(ar.tripsTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('trips-empty')), findsOneWidget);
    expect(find.text(ar.tripDeleted), findsOneWidget);
    await disposeApp(t);
  });

  testWidgets('رحلة غير موجودة: رسالة خطأ', (t) async {
    final f = HomeFakes();
    await pumpApp(t, f, initial: AppRoutes.tripFor('nope'));
    await settle(t);
    expect(find.byKey(const ValueKey('trip-error')), findsOneWidget);
    await disposeApp(t);
  });

  group('المشاركة (F10)', () {
    Future<void> openShare(WidgetTester t) async {
      await t.tap(find.byKey(const ValueKey('trip-share')));
      await t.pumpAndSettle();
    }

    testWidgets('خياران واضحان وتنبيه واتساب', (t) async {
      await open(t);
      await t.ensureVisible(find.byKey(const ValueKey('trip-share')));
      await openShare(t);
      expect(find.text(ar.shareVideoTitle), findsOneWidget);
      expect(find.text(ar.shareRouteTitle), findsOneWidget);
      expect(find.text(ar.shareVideoWarning), findsOneWidget);
      expect(
        t.getSize(find.byKey(const ValueKey('share-video'))).height,
        greaterThanOrEqualTo(88),
      );
      await disposeApp(t);
    });

    testWidgets('إرسال الفيديو يشارك ملف الفيديو', (t) async {
      final (f, _) = await open(t);
      await openShare(t);
      await t.tap(find.byKey(const ValueKey('share-video')));
      await t.pumpAndSettle();
      expect(f.share.files, [_video]);
      await disposeApp(t);
    });

    testWidgets('الفيديو مفقود: البطاقة معطّلة بسبب مكتوب', (t) async {
      final (f, _) = await open(t, videoOnDisk: false);
      await openShare(t);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('share-video')),
          matching: find.text(ar.shareVideoMissing),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('share-video')));
      await t.pumpAndSettle();
      expect(f.share.files, isEmpty);
      await disposeApp(t);
    });

    testWidgets('فشل المشاركة: Snackbar', (t) async {
      final share = FakeShareService(existing: {_video})..failShare = true;
      await open(t, share: share);
      await openShare(t);
      await t.tap(find.byKey(const ValueKey('share-video')));
      await t.pumpAndSettle();
      expect(find.text(ar.shareFailed), findsOneWidget);
      await disposeApp(t);
    });

    testWidgets('مساري: رابط جوجل نصاً بـtravelmode وفتحه في خرائط جوجل', (
      t,
    ) async {
      final (f, _) = await open(t);
      await openShare(t);
      await t.tap(find.byKey(const ValueKey('share-route')));
      await t.pumpAndSettle();
      expect(find.text(ar.shareLinkTitle), findsOneWidget);
      expect(find.text(ar.shareGpxTitle), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('share-link-share')));
      await t.pumpAndSettle();
      expect(f.share.texts, hasLength(1));
      final url = RegExp(r'https://\S+')
          .firstMatch(f.share.texts.single)!
          .group(0)!;
      expect(url, startsWith('https://www.google.com/maps/dir/'));
      expect(url, contains('travelmode=driving'));
      expect(url.length, lessThanOrEqualTo(2048));

      await t.tap(find.byKey(const ValueKey('share-link-open')));
      await t.pumpAndSettle();
      expect(f.share.openedUrls.single, url);
      await disposeApp(t);
    });

    testWidgets('فتح خرائط جوجل يفشل: رسالة', (t) async {
      final share = FakeShareService(existing: {_video})..openUrlResult = false;
      await open(t, share: share);
      await openShare(t);
      await t.tap(find.byKey(const ValueKey('share-route')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('share-link-open')));
      await t.pumpAndSettle();
      expect(find.text(ar.openMapsFailed), findsOneWidget);
      await disposeApp(t);
    });

    testWidgets('ملف GPX صحيح بكل النقاط يُشارك كملف', (t) async {
      final (f, _) = await open(t);
      await openShare(t);
      await t.tap(find.byKey(const ValueKey('share-route')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('share-gpx')));
      await t.pumpAndSettle();
      final g = f.share.generated.single;
      expect(g.name, endsWith('.gpx'));
      expect(g.mime, 'application/gpx+xml');
      final doc = XmlDocument.parse(g.content);
      expect(doc.findAllElements('trkpt'), hasLength(5));
      await disposeApp(t);
    });
  });

  testWidgets('الملخص: زر «عرض الرحلة» مفعّل ويفتح التفاصيل', (t) async {
    final f = HomeFakes();
    final id = await seedTrip(t, f.repo, videoPath: _video);
    await pumpApp(t, f, initial: AppRoutes.summaryFor(id));
    await settle(t);
    final btn = find.byKey(const ValueKey('summary-view-trip'));
    expect(t.widget<OutlinedButton>(btn).onPressed, isNotNull);
    await t.ensureVisible(btn);
    await t.tap(btn);
    await settle(t);
    expect(find.text(ar.tripDetailsTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-distance')), findsOneWidget);
    // رجوع من التفاصيل (لا سجل تنقل) يذهب إلى «رحلاتي».
    await t.tap(find.byKey(const ValueKey('trip-back')));
    await settle(t);
    expect(find.text(ar.tripsTitle), findsOneWidget);
    await disposeApp(t);
  });
}
