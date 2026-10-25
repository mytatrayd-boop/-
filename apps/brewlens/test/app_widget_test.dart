import 'package:brewlens/app/app.dart';
import 'package:brewlens/app/providers.dart';
import 'package:brewlens/backend/demo/demo_auth_repository.dart';
import 'package:brewlens/features/auth/login_screen.dart';
import 'package:brewlens/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester, {String locale = 'ar', bool signedIn = false}) async {
  SharedPreferences.setMockInitialValues({
    'locale': locale,
    if (signedIn)
      DemoAuthRepository.sessionKey: '{"user_id":"demo-a@b.co","email":"a@b.co"}',
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: demoOverrides(prefs, latency: Duration.zero),
    child: const BrewLensApp(),
  ));
  await tester.pumpAndSettle();
}

TextDirection directionOf(WidgetTester tester, Type screen) =>
    Directionality.of(tester.element(find.byType(screen)));

void main() {
  testWidgets('Arabic: RTL, demo banner, redirect to login without session', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(directionOf(tester, LoginScreen), TextDirection.rtl);
    expect(find.text('نسخة عرض — البيانات تجريبية'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets('English: LTR and English banner', (tester) async {
    await pumpApp(tester, locale: 'en');
    expect(directionOf(tester, LoginScreen), TextDirection.ltr);
    expect(find.text('Demo build — sample data'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('tapping the banner explains the demo build', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('نسخة عرض — البيانات تجريبية'));
    await tester.pumpAndSettle();
    expect(find.text('هذه نسخة للمراجعة، لا تتصل بالخادم ولا بالمتجر.'), findsOneWidget);
  });

  testWidgets('validation messages appear before sending', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('email')), 'bad');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل بريداً إلكترونياً صحيحاً'), findsOneWidget);
    expect(find.text('كلمة المرور 6 أحرف على الأقل'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('sign in goes home with the counter, sign out returns to login', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('email')), 'a@b.co');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('متبقٍّ لك اليوم: 2 من 2'), findsOneWidget);
    expect(find.text('نسخة عرض — البيانات تجريبية'), findsOneWidget);

    await tester.tap(find.byTooltip('تسجيل الخروج'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('stored session opens home directly', (tester) async {
    await pumpApp(tester, signedIn: true);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('احصل على تقييم المظهر ونصيحة باريستا'), findsOneWidget);
  });

  testWidgets('signup screen explains why an account is needed', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('أنشئ حساباً'));
    await tester.pumpAndSettle();
    expect(find.text('نحتاج حساباً لحفظ سجلك ومقاهيك وحماية محاولاتك اليومية'), findsOneWidget);
    expect(find.text('6 أحرف على الأقل'), findsOneWidget);
  });

  testWidgets('forgot password shows the sent state in demo', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('email')), 'a@b.co');
    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await tester.pumpAndSettle();
    expect(find.text('a@b.co'), findsOneWidget); // البريد نُقل من شاشة الدخول.
    await tester.tap(find.text('إرسال الرابط'));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.text('أرسلنا الرابط إلى a@b.co، تحقق من البريد المزعج أيضاً'), findsOneWidget);
    expect(find.text('إعادة الإرسال (60)'), findsOneWidget);
    // إنهاء العدّاد حتى لا يبقى Timer معلّقاً.
    await tester.pump(const Duration(seconds: 61));
  });
}
