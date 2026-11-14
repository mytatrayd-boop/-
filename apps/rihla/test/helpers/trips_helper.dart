import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/app.dart';
import 'package:rihla/core/locale/locale_provider.dart';
import 'package:rihla/core/router/app_router.dart';
import 'package:rihla/data/repositories/trip_repository.dart';

import 'fakes.dart';

class FixedLocale extends LocaleNotifier {
  FixedLocale(this.l);
  final Locale l;
  @override
  Locale? build() => l;
}

const portrait = Size(400, 800);
const landscape = Size(800, 360);

/// يشغّل التطبيق الكامل (الراوتر الحقيقي) بالمزيّفات، طولياً افتراضياً.
Future<ProviderContainer> pumpApp(
  WidgetTester t,
  HomeFakes f, {
  String initial = AppRoutes.home,
  Locale locale = const Locale('ar'),
  Size size = portrait,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...f.overrides,
        initialLocationProvider.overrideWithValue(initial),
        localeProvider.overrideWith(() => FixedLocale(locale)),
      ],
      child: const RihlaApp(),
    ),
  );
  await t.pumpAndSettle();
  return ProviderScope.containerOf(t.element(find.byType(RihlaApp)));
}

/// drift يجدول مؤقتاً عند إلغاء استعلام: نفكّ الشجرة ونتركه ينتهي.
Future<void> disposeApp(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(milliseconds: 10));
}

/// ينتظر IO قاعدة البيانات الحقيقي ثم يرسم.
Future<void> settle(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await t.pumpAndSettle();
}

/// يزرع رحلة مكتملة بنقاط. يعيد المعرّف.
Future<String> seedTrip(
  WidgetTester t,
  TripRepository repo, {
  DateTime? start,
  int points = 5,
  String? videoPath,
}) async {
  return (await t.runAsync(() async {
    final s = start ?? DateTime.utc(2026, 3, 5, 10);
    final id = await repo.startTrip(startedAt: s);
    await repo.addPoints(id, [
      for (var i = 0; i < points; i++)
        TrackSample(
          lat: 24.7 + i * 0.001,
          lng: 46.6 + i * 0.001,
          ts: s.add(Duration(seconds: 30 * i)),
          accuracyM: 5,
        ),
    ]);
    await repo.completeTrip(
      id,
      endedAt: s.add(Duration(seconds: 30 * points)),
      videoPath: videoPath,
    );
    return id;
  }))!;
}
