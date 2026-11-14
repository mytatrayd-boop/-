import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/data/repositories/trip_repository.dart';
import 'package:rihla/data/db/app_database.dart';
import 'package:rihla/features/trips/trips_screen.dart';
import 'package:rihla/l10n/app_localizations_ar.dart';
import 'package:rihla/l10n/app_localizations_en.dart';

import '../../helpers/fakes.dart';
import '../../helpers/trips_helper.dart';

void main() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();

  for (final loc in ['ar', 'en']) {
    final s = loc == 'ar' ? ar : en;

    testWidgets('«رحلاتي»: فراغ وزر رحلة جديدة كبير ($loc)', (t) async {
      final f = HomeFakes();
      await pumpApp(t, f, locale: Locale(loc));
      expect(find.text(s.tripsTitle), findsOneWidget);
      expect(find.text(s.tripsEmpty), findsOneWidget);
      final btn = t.getSize(find.byKey(const ValueKey('trips-new')));
      expect(btn.height, greaterThanOrEqualTo(64));
      expect(find.text(s.tripsNew), findsOneWidget);
      expect(
        Directionality.of(t.element(find.text(s.tripsTitle))),
        loc == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(t.takeException(), isNull);
      await disposeApp(t);
    });
  }

  testWidgets('قائمة: الأحدث أولاً مع التاريخ والمسافة والمدة والحالة', (
    t,
  ) async {
    final f = HomeFakes();
    // الزرع قبل تشغيل الشاشة (مستمع drift الحيّ يعلّق الكتابة داخل runAsync).
    final old = await seedTrip(t, f.repo, start: DateTime.utc(2026, 1, 2, 8));
    final recent = await seedTrip(
      t,
      f.repo,
      start: DateTime.utc(2026, 3, 5, 10),
      videoPath: '/v.mp4',
    );
    // رحلة منقطعة بلا فيديو.
    final cut = (await t.runAsync(() async {
      final id = await f.repo.startTrip(startedAt: DateTime.utc(2025, 12, 1));
      await f.repo.interruptTrip(id, endedAt: DateTime.utc(2025, 12, 1, 0, 5));
      return id;
    }))!;
    await pumpApp(t, f);
    final ids = [
      for (final w in t.widgetList<TripCard>(find.byType(TripCard))) w.trip.id,
    ];
    expect(ids, [recent, old, cut]);
    expect(find.text(ar.tripStatusInterrupted), findsOneWidget);
    expect(find.text(ar.tripStatusCompleted), findsNWidgets(2));
    expect(find.text(ar.tripNoVideoChip), findsNWidgets(2));
    // مدة 5 نقاط x 30ث = 02:30
    expect(find.text('02:30'), findsNWidgets(2));
    expect(find.textContaining('0.'), findsWidgets);
    expect(t.takeException(), isNull);
    await disposeApp(t);
  });

  testWidgets('خطأ تحميل: رسالة وزر إعادة المحاولة', (t) async {
    late _Flaky repo;
    final f = HomeFakes(repoBuilder: (db) => repo = _Flaky(db));
    await pumpApp(t, f);
    expect(find.byKey(const ValueKey('trips-error')), findsOneWidget);
    expect(find.text(ar.tripsLoadError), findsOneWidget);
    repo.fail = false;
    await t.tap(find.byKey(const ValueKey('trips-retry')));
    await settle(t);
    expect(find.byKey(const ValueKey('trips-error')), findsNothing);
    expect(find.byKey(const ValueKey('trips-empty')), findsOneWidget);
    await disposeApp(t);
  });
}

class _Flaky extends TripRepository {
  _Flaky(super.db);
  bool fail = true;
  @override
  Stream<List<TripRow>> watchTrips() =>
      fail ? Stream.error(StateError('x')) : super.watchTrips();
}
