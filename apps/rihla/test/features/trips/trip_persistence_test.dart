import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/data/db/app_database.dart';
import 'package:rihla/data/repositories/trip_repository.dart';
import 'package:rihla/features/trips/trips_screen.dart';
import 'package:rihla/l10n/app_localizations_ar.dart';

import '../../helpers/fakes.dart';
import '../../helpers/trips_helper.dart';
import '../home/home_screen_test.dart' show fixAndStart, settleDb;

/// ملاحظة المالك 1 (حرج): الرحلة والمسار يجب أن يُحفظا ويظهرا في «رحلاتي».
void main() {
  final ar = AppLocalizationsAr();

  testWidgets('رحلة كاملة من «رحلاتي»: تسجيل ثم إنهاء ثم تظهر بنقاطها', (
    t,
  ) async {
    final f = HomeFakes();
    await pumpApp(t, f);
    expect(find.byKey(const ValueKey('trips-empty')), findsOneWidget);

    // «رحلة جديدة» تفتح شاشة التسجيل وتفرض الأفقي.
    await t.tap(find.byKey(const ValueKey('trips-new')));
    await t.pumpAndSettle();
    expect(f.orientation.calls, ['landscape']);
    t.view.physicalSize = landscape; // يدور الجهاز.
    await t.pumpAndSettle();

    await fixAndStart(t, f);
    // نقاط GPS حقيقية الشكل (دقة 8م، سرعة معقولة) تُدفع عبر LocationSource.
    for (var i = 1; i <= 4; i++) {
      f.location.pushAt(
        24.7 + 0.001 * i,
        46.6 + 0.001 * i,
        accuracy: 8,
        time: DateTime.utc(2026, 1, 1, 0, 0, 20 * i),
      );
      await t.pump();
      await t.pump();
    }
    await settleDb(t);

    await t.tap(find.byKey(const ValueKey('stop-button')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('stop-confirm')));
    await settleDb(t);
    await t.pumpAndSettle();

    // الخروج من التسجيل يعيد الطولي ويظهر الملخص.
    expect(f.orientation.calls, ['landscape', 'portrait']);
    t.view.physicalSize = portrait;
    await t.pumpAndSettle();
    expect(find.text(ar.summarySaved), findsOneWidget);

    // القاعدة: رحلة مكتملة بخمس نقاط وفيديو.
    final trips = (await t.runAsync(() => f.repo.watchTrips().first))!;
    expect(trips, hasLength(1));
    expect(trips.single.status, TripStatus.completed);
    expect(trips.single.videoPath, isNotNull);
    final pts = (await t.runAsync(() => f.repo.getPoints(trips.single.id)))!;
    expect(pts, hasLength(5));

    // «رحلاتي» فيها الرحلة الجديدة.
    await t.tap(find.byKey(const ValueKey('summary-my-trips')));
    await t.pumpAndSettle();
    expect(find.byType(TripCard), findsOneWidget);
    expect(find.byKey(const ValueKey('trips-empty')), findsNothing);
    expect(find.text(ar.tripStatusCompleted), findsOneWidget);

    // وتفاصيلها تعرض المسار (خط) على الخريطة.
    await t.tap(find.byType(TripCard));
    await t.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-distance')), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeApp(t);
  });

  test(
    'قاعدة القرص: الرحلة ونقاطها تبقى بعد إغلاق القاعدة وإعادة فتحها',
    () async {
      final dir = Directory.systemTemp.createTempSync('rihla_db_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/rihla.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      var repo = TripRepository(db);
      final s = DateTime.utc(2026, 3, 5, 10);
      final id = await repo.startTrip(startedAt: s);
      final saved = await repo.addPoints(id, [
        for (var i = 0; i < 6; i++)
          TrackSample(
            lat: 24.7 + i * 0.001,
            lng: 46.6,
            ts: s.add(Duration(seconds: 20 * i)),
            accuracyM: 12,
            speedMps: 5,
          ),
      ]);
      expect(saved, 6);
      await repo.completeTrip(id, videoPath: '/v.mp4');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      repo = TripRepository(db);
      final trips = await repo.watchTrips().first;
      expect(trips.single.id, id);
      expect(trips.single.status, TripStatus.completed);
      expect(trips.single.distanceM, greaterThan(500));
      expect(await repo.getPoints(id), hasLength(6));
      await db.close();
    },
  );
}
