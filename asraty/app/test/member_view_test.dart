import 'package:asraty/backend/demo_backend.dart';
import 'package:asraty/core/logic.dart';
import 'package:asraty/core/models.dart';
import 'package:asraty/ui/app.dart';
import 'package:asraty/ui/providers.dart';
import 'package:flutter/material.dart';
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
  testWidgets('member: sign-out in the header, honor board, private rewards only for their owner', (tester) async {
    await openAs(tester, 'aseel@demo.sa', Role.member);
    expect(find.text('🚪 خروج'), findsOneWidget);

    await tester.tap(find.text('المكافآت'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🏆 لوحة الشرف'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('حفظ سورة الملك'), 200);
    expect(find.text('حفظ سورة الملك'), findsOneWidget, reason: "Aseel's own monthly goal");
    // Lama's private reward never shows for Aseel.
    expect(find.textContaining('كتاب تختاره'), findsNothing);
    // Members cannot add goals.
    expect(find.text('إضافة الهدف'), findsNothing);
  });

  testWidgets('member sees their private reward', (tester) async {
    await openAs(tester, 'lama@demo.sa', Role.member);
    await tester.tap(find.text('المكافآت'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('كتاب تختاره'), findsOneWidget);
  });

  testWidgets('ended alerts move to their own list', (tester) async {
    final c = await openAs(tester, 'abu@demo.sa', Role.admin);
    final b = c.read(backendProvider) as DemoBackend;
    final aseel = b.current.data!.members.firstWhere((m) => m.name == 'أصيل');
    await b.sendAlert(aseel.id, 'تنبيه انتهى', minutes: 30);
    await b.sendAlert(aseel.id, 'تنبيه دائم');
    // Re-open as Aseel; the 30-minute alert is still active, so both are listed as current.
    await b.signOut();
    await b.requestCode(email: 'aseel@demo.sa', role: Role.member, resend: true);
    await b.verifyCode(email: 'aseel@demo.sa', code: RegExp(r'كود التحقق: (\d{6})').firstMatch(b.outbox.first.body)!.group(1)!);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('التنبيهات'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تنبيه انتهى'), findsOneWidget);
    expect(find.text('تنبيه دائم'), findsOneWidget);
    expect(find.textContaining('ينتهي الساعة'), findsOneWidget);
    expect(find.text('تنبيهات منتهية'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
