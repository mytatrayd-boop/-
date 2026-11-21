import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:lamha/l10n/app_localizations.dart';
import 'package:lamha/src/app/access.dart';
import 'package:lamha/src/app/paywall.dart';
import 'package:lamha/src/app/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRedeemer implements CodeRedeemer {
  final calls = <(String, String)>[];
  @override
  Future<void> redeem(String code, String deviceId) async {
    calls.add((code, deviceId));
    if (code.toUpperCase() != 'LAM-GOOD-0001') throw ReceiptCheckError(code.toUpperCase() == 'LAM-USED-0001' ? 'code-used' : 'code-invalid');
  }
}

class _FakeChecker implements ReceiptChecker {
  _FakeChecker(this.until);
  final int? until;
  @override
  Future<int?> check(String receipt) async => until;
}

Widget app(SharedPreferences prefs) => ProviderScope(
      overrides: [
        preferencesProvider.overrideWith((ref) async => prefs),
        receiptCheckerProvider.overrideWithValue(_FakeChecker(null)),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AccessGate(child: Scaffold(body: Text('الشاشة الرئيسية'))),
      ),
    );

void main() {
  tearDown(() {
    LamhaAccess.debugGated = null;
    LamhaAccess.debugDeviceId = null;
    LamhaStore.debugNoStart = false;
  });

  test('the server is told which store to ask: Android sends platform=android, iPhone ios', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(LamhaAccess.platform, 'ios');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(LamhaAccess.platform, 'android');
    debugDefaultTargetPlatformOverride = null;
  });

  test('access: free when the gate is off; paid only until the server-confirmed end', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026, 12, 1);
    LamhaAccess.debugGated = false;
    expect(LamhaAccess.allowed(p, now), isTrue);
    LamhaAccess.debugGated = true;
    expect(LamhaAccess.allowed(p, now), isFalse, reason: 'never paid');
    await LamhaAccess.savePaidUntil(p, now.add(const Duration(days: 3)).millisecondsSinceEpoch);
    expect(LamhaAccess.allowed(p, now), isTrue);
    expect(LamhaAccess.allowed(p, now.add(const Duration(days: 4))), isFalse, reason: 'the subscription ended');
    expect(LamhaAccess.productIds, {'lamha.monthly', 'lamha.yearly'});
  });


  test('Google Play plan: the price after the free week, and whether this account still gets the trial', () {
    PricingPhaseWrapper phase(int micros, String text, RecurrenceMode mode) => PricingPhaseWrapper(
        billingCycleCount: 1, billingPeriod: 'P1M', formattedPrice: text, priceAmountMicros: micros, priceCurrencyCode: 'SAR', recurrenceMode: mode);
    final products = GooglePlayProductDetails.fromProductDetails(ProductDetailsWrapper(
      description: '',
      name: 'شهري',
      productId: LamhaAccess.monthlyId,
      productType: ProductType.subs,
      title: 'شهري',
      subscriptionOfferDetails: [
        SubscriptionOfferDetailsWrapper(basePlanId: 'm', offerId: 'trial', offerTags: const [], offerIdToken: 'a', pricingPhases: [
          phase(0, 'مجانية', RecurrenceMode.finiteRecurring),
          phase(10000000, '١٠٫٠٠ ر.س.', RecurrenceMode.infiniteRecurring),
        ]),
        SubscriptionOfferDetailsWrapper(basePlanId: 'm', offerTags: const [], offerIdToken: 'b', pricingPhases: [
          phase(10000000, '١٠٫٠٠ ر.س.', RecurrenceMode.infiniteRecurring),
        ]),
      ],
    ));
    final trial = LamhaStore.offer(products[0]);
    expect(trial.price, '١٠٫٠٠ ر.س.', reason: 'not «مجانية»: the price paid after the trial');
    expect(trial.trial, isTrue);
    final paid = LamhaStore.offer(products[1]);
    expect(paid.price, '١٠٫٠٠ ر.س.');
    expect(paid.trial, isFalse, reason: 'trial already used: the button says «اشترك»');
  });

  testWidgets('an activation code opens the app on this phone; a wrong or used code says why', (tester) async {
    LamhaStore.debugNoStart = true;
    LamhaAccess.debugGated = true;
    LamhaAccess.debugDeviceId = 'a-test-device';
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final redeemer = _FakeRedeemer();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        preferencesProvider.overrideWith((ref) async => prefs),
        receiptCheckerProvider.overrideWithValue(_FakeChecker(null)),
        codeRedeemerProvider.overrideWithValue(redeemer),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AccessGate(child: Scaffold(body: Text('الشاشة الرئيسية'))),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('عندي كود تفعيل'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lam-used-0001');
    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();
    expect(find.text('هذا الكود مستخدم على جهاز آخر.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();
    expect(find.text('الكود غير صحيح.'), findsOneWidget);
    expect(LamhaAccess.savedCode(prefs), isNull);

    await tester.enterText(find.byType(TextField), ' lam-good-0001 ');
    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();
    expect(redeemer.calls.last, ('lam-good-0001', 'a-test-device'));
    expect(LamhaAccess.savedCode(prefs), 'LAM-GOOD-0001');
    expect(find.text('الشاشة الرئيسية'), findsOneWidget);
    expect(LamhaAccess.allowed(prefs, DateTime.now()), isTrue, reason: 'a code needs no subscription');
  });
  testWidgets('the gate shows the subscription screen until paid, then the app', (tester) async {
    LamhaStore.debugNoStart = true;
    LamhaAccess.debugGated = true;
    SharedPreferences.setMockInitialValues({});
    var prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(app(prefs));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('اشترك في لمحة'), findsOneWidget);
    expect(find.text('الشاشة الرئيسية'), findsNothing);
    expect(find.text('شهري'), findsOneWidget);
    expect(find.text('سنوي'), findsOneWidget);
    expect(find.text('استعادة المشتريات'), findsOneWidget);

    // A subscription the server confirmed opens the app.
    SharedPreferences.setMockInitialValues({'lamhaPaidUntil': DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch});
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(UncontrolledProviderScope(container: ProviderContainer(overrides: [
      preferencesProvider.overrideWith((ref) async => prefs),
      receiptCheckerProvider.overrideWithValue(_FakeChecker(null)),
    ]), child: const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: AccessGate(child: Scaffold(body: Text('الشاشة الرئيسية'))),
    )));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('الشاشة الرئيسية'), findsOneWidget);
  });
}
