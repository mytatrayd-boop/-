import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/l10n/app_localizations.dart';
import 'package:lamha/src/app/access.dart';
import 'package:lamha/src/app/paywall.dart';
import 'package:lamha/src/app/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    LamhaStore.debugNoStart = false;
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
