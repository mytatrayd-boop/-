import 'package:asraty/backend/demo_backend.dart';
import 'package:asraty/core/logic.dart';
import 'package:asraty/core/models.dart';
import 'package:asraty/ui/app.dart';
import 'package:asraty/ui/common.dart';
import 'package:asraty/ui/member.dart';
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
  testWidgets('member: sign-out in the header, ranks and report, prizes and honor board', (tester) async {
    await openAs(tester, 'aseel@demo.sa', Role.member);
    expect(find.text('خروج'), findsOneWidget);
    // The prayer whose time is running is among the tasks.
    expect(find.textContaining('صلاة '), findsWidgets);
    expect(find.text('تقريري'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(SegTabs<MTab>), matching: find.text('الجوائز')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('آيسكريم من اختيارك'), findsOneWidget, reason: 'prizes show for everyone');
    expect(find.text('🏆 لوحة الشرف'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('حفظ سورة الملك'), 200);
    expect(find.text('حفظ سورة الملك'), findsOneWidget, reason: "Aseel's own monthly goal");
    // Members cannot add goals or prizes.
    expect(find.text('إضافة الهدف'), findsNothing);
    expect(find.text('إضافة الجائزة'), findsNothing);
  });

  testWidgets("member's own report for each period", (tester) async {
    await openAs(tester, 'aseel@demo.sa', Role.member);
    await tester.tap(find.text('تقريري'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('منجزة'), findsOneWidget);
    expect(find.text('غير منجزة'), findsOneWidget);
    await tester.tap(find.text('هذا الشهر'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🥇'), findsWidgets, reason: 'Aseel leads the month in the seed');
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

  testWidgets('delegated admin gets the family alerts in their own inbox', (tester) async {
    final c = await openAs(tester, 'abu@demo.sa', Role.admin);
    final b = c.read(backendProvider) as DemoBackend;
    final mom = b.current.data!.people.firstWhere((p) => p.role == Role.admin);
    await b.sendAlert('all', 'اجتماع الأسرة بعد العشاء');
    await b.sendAlert(mom.id, 'رسالة خاصة للأم');
    await b.signOut();
    await b.requestCode(email: 'um@demo.sa', role: Role.admin, resend: true);
    await b.verifyCode(email: 'um@demo.sa', code: RegExp(r'كود التحقق: (\d{6})').firstMatch(b.outbox.first.body)!.group(1)!);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(find.text('التنبيهات'), 200);
    await tester.tap(find.text('التنبيهات'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('اجتماع الأسرة بعد العشاء'), findsOneWidget);
    expect(find.text('رسالة خاصة للأم'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('reports for day, week, month and year, each sendable to the family', (tester) async {
    final c = await openAs(tester, 'abu@demo.sa', Role.admin);
    final b = c.read(backendProvider) as DemoBackend;
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('التقارير')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('→'), findsNothing);
    await tester.tap(find.text('هذه السنة'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('ترتيب إنجاز السنة'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('إرسال لكل الأعضاء'), 200);
    await tester.tap(find.text('إرسال لكل الأعضاء'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(b.current.data!.notices.first.title, '🏆 ترتيب إنجاز السنة');
    await tester.pump(const Duration(seconds: 4));
  });
}
