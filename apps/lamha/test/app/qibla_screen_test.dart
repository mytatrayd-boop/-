import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/qibla_screen.dart';
import 'package:lamha/src/engine/qibla.dart';

import 'app_helpers.dart';

QiblaCompassPainter painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const Key('qibla-compass')))
    .painter! as QiblaCompassPainter;

Future<void> openQibla(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('qibla-button')));
  // لا pumpAndSettle: مؤشر الانتظار يدور حتى أول قراءة.
  await _pumpRoute(tester);
}

/// الصفحة الجديدة خارج الشاشة في أول إطار (Hero)، فثلاثة إطارات تكفي لظهورها.
Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  // الرياض (أول مدينة في القائمة، الافتراضية).
  final riyadhQibla = double.parse(qiblaDegrees(24.6877, 46.7219).toStringAsFixed(1));

  testWidgets('زر «اتجاه القبلة» يفتح البوصلة الحية والسهم يتبع الجهاز', (tester) async {
    final compass = FakeCompass();
    await pumpApp(tester, compass: compass);
    await openQibla(tester);
    expect(find.byType(QiblaScreen), findsOneWidget);
    expect(find.text('اتجاه القبلة'), findsOneWidget);
    expect(find.byKey(const Key('qibla-angle')), findsOneWidget);
    expect(find.textContaining('من الشمال'), findsOneWidget);
    expect(find.text('جارٍ قراءة البوصلة…'), findsOneWidget);

    compass.controller.add((heading: 0, accuracy: 15));
    await tester.pump();
    expect(painter(tester).arrow, closeTo(riyadhQibla, 0.01));
    expect(find.byKey(const Key('compass-calibrate')), findsNothing);

    compass.controller.add((heading: 300, accuracy: 15));
    await tester.pump();
    expect(painter(tester).arrow, closeTo((riyadhQibla - 300 + 360) % 360, 0.01));
  });

  testWidgets('دقة منخفضة: رسالة معايرة', (tester) async {
    final compass = FakeCompass();
    await pumpApp(tester, compass: compass);
    await openQibla(tester);
    compass.controller.add((heading: 10, accuracy: 45));
    await tester.pump();
    expect(find.byKey(const Key('compass-calibrate')), findsOneWidget);
    expect(find.textContaining('على شكل الرقم ٨'), findsOneWidget);
  });

  testWidgets('بلا حساس: رسالة واضحة والزاوية ظاهرة', (tester) async {
    await pumpApp(tester, compass: FakeCompass(available: false));
    await openQibla(tester);
    expect(find.byKey(const Key('compass-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('qibla-compass')), findsNothing);
    expect(find.byKey(const Key('qibla-angle')), findsOneWidget);
  });

  testWidgets('حساس لا يرسل شيئاً: رسالة عدم التوفر بعد المهلة', (tester) async {
    await pumpApp(tester);
    await openQibla(tester);
    expect(find.byKey(const Key('compass-unavailable')), findsNothing);
    await tester.pump(QiblaScreen.sensorTimeout);
    await tester.pump();
    expect(find.byKey(const Key('compass-unavailable')), findsOneWidget);
  });

  testWidgets('اتجاه فارغ من الحساس = غير متوفر', (tester) async {
    final compass = FakeCompass();
    await pumpApp(tester, compass: compass);
    await openQibla(tester);
    compass.controller.add((heading: null, accuracy: null));
    await tester.pump();
    expect(find.byKey(const Key('compass-unavailable')), findsOneWidget);
  });

  testWidgets('فتح التطبيق من مربع القبلة في الودجت يفتح البوصلة', (tester) async {
    await pumpApp(tester, launch: FakeLaunch(Uri.parse('lamha://qibla')));
    expect(find.byType(QiblaScreen), findsOneWidget);
  });

  testWidgets('الضغط على الودجت والتطبيق مفتوح: القبلة ثم الإعدادات', (tester) async {
    final launch = FakeLaunch();
    await pumpApp(tester, launch: launch);
    expect(find.byType(QiblaScreen), findsNothing);
    launch.controller.add(Uri.parse('lamha://qibla'));
    await _pumpRoute(tester);
    expect(find.byType(QiblaScreen), findsOneWidget);
    // بقية الودجت (بلا رابط) تعيد للإعدادات.
    launch.controller.add(Uri());
    await _pumpRoute(tester);
    expect(find.byType(QiblaScreen), findsNothing);
    expect(find.byKey(const Key('qibla-button')), findsOneWidget);
  });

  testWidgets('الفتح العادي (لا من الودجت) يبقى على الإعدادات', (tester) async {
    await pumpApp(tester, launch: FakeLaunch(null));
    expect(find.byType(QiblaScreen), findsNothing);
  });
}
