import 'package:asraty/backend/demo_backend.dart';
import 'package:asraty/core/models.dart';
import 'package:asraty/ui/app.dart';
import 'package:asraty/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens the app signed in to the demo family as [email].
Future<ProviderContainer> openAs(WidgetTester tester, String email, Role role) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  c.read(backendProvider.notifier).startDemo();
  final b = c.read(backendProvider) as DemoBackend;
  await b.signOut();
  await b.requestCode(email: email, role: role, resend: true);
  final code = RegExp(r'كود التحقق: (\d{6})').firstMatch(b.outbox.first.body)!.group(1)!;
  await b.verifyCode(email: email, code: code);
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const AsratyApp()));
  await tester.pump(const Duration(milliseconds: 300));
  return c;
}

void main() {
  testWidgets('trip: owner starts it from the dashboard; a member then sees the big button and the family list', (tester) async {
    final c = await openAs(tester, 'abu@demo.sa', Role.owner);
    // The owner has the tile and starts a trip.
    await tester.scrollUntilVisible(find.text('أنا هنا'), 200);
    await tester.tap(find.text('أنا هنا'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text('بدء رحلة').first, 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('بدء رحلة').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final b = c.read(backendProvider) as DemoBackend;
    expect(b.current.data!.trip!.active, isTrue);
    expect(find.text('إنهاء الرحلة'), findsOneWidget);
    expect(find.text('ساعدوني'), findsOneWidget);
    expect(find.text('أين أسرتي'), findsOneWidget);
    // Nobody shared a place yet, so there is no map; after the first place it appears.
    expect(find.byType(FlutterMap), findsNothing);
    await b.tripPing(lat: 24.7136, lng: 46.6753, acc: 8);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('trip: a member has no start button, sees the banner only while a trip is live', (tester) async {
    final c = await openAs(tester, 'aseel@demo.sa', Role.member);
    expect(find.text('أنا هنا'), findsNothing);
    final b = c.read(backendProvider) as DemoBackend;
    await b.signOut();
    await b.requestCode(email: 'abu@demo.sa', role: Role.owner, resend: true);
    final code = RegExp(r'كود التحقق: (\d{6})').firstMatch(b.outbox.first.body)!.group(1)!;
    await b.verifyCode(email: 'abu@demo.sa', code: code);
    await b.tripStart();
    await b.signOut();
    await b.requestCode(email: 'aseel@demo.sa', role: Role.member, resend: true);
    final code2 = RegExp(r'كود التحقق: (\d{6})').firstMatch(b.outbox.first.body)!.group(1)!;
    await b.verifyCode(email: 'aseel@demo.sa', code: code2);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('أنا هنا'), findsOneWidget);
    await tester.tap(find.text('أنا هنا'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('بدء رحلة'), findsNothing);
    expect(find.text('إنهاء الرحلة'), findsNothing);
    expect(find.text('ساعدوني'), findsOneWidget);
    expect(find.text('أين أسرتي'), findsOneWidget);
  });

  testWidgets('places: the owner touches the map, names the place, saves it, and it shows in the saved list', (tester) async {
    final c = await openAs(tester, 'abu@demo.sa', Role.owner);
    await tester.scrollUntilVisible(find.text('أنا هنا'), 200);
    await tester.tap(find.text('أنا هنا'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text('اختر مكانًا على الخريطة').first, 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('اختر مكانًا على الخريطة').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(FlutterMap), findsOneWidget);
    // Saving before touching the map asks to touch it first.
    await tester.tap(find.text('حفظ فقط'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('المس الخريطة أولاً لتحديد المكان.'), findsOneWidget);
    expect(find.text('المس الخريطة لتحديد المكان'), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    // The map waits a moment to tell a tap from a double tap.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'بوابة ٣');
    await tester.tap(find.text('حفظ فقط'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final b = c.read(backendProvider) as DemoBackend;
    expect(b.current.data!.places.single.label, 'بوابة ٣');
    expect(find.text('بوابة ٣'), findsWidgets);
  });
}
