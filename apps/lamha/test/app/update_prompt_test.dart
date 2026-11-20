import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/l10n/app_localizations.dart';
import 'package:lamha/src/app/update_service.dart';

class _FakeChecker implements UpdateChecker {
  _FakeChecker(this.update);
  final AppUpdate? update;
  var checks = 0;
  final started = <AppUpdate>[];
  @override
  Future<AppUpdate?> check() async {
    checks++;
    return update;
  }

  @override
  Future<void> start(AppUpdate u) async => started.add(u);
}

Widget app(UpdateChecker checker) => ProviderScope(
      overrides: [updateCheckerProvider.overrideWithValue(checker)],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: UpdatePrompt(child: Scaffold(body: Text('الرئيسية'))),
      ),
    );

void main() {
  testWidgets('تحديث متاح: نافذة تنبيه، و«حدّث الآن» تنقل إلى التنزيل', (tester) async {
    final c = _FakeChecker(const AppUpdate(storeUrl: 'https://apps.apple.com/app/x'));
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    expect(find.text('يتوفر تحديث جديد'), findsOneWidget);
    await tester.tap(find.byKey(const Key('update-now')));
    await tester.pumpAndSettle();
    expect(c.started.single.storeUrl, 'https://apps.apple.com/app/x');
    expect(find.text('يتوفر تحديث جديد'), findsNothing);
  });

  testWidgets('«لاحقاً» تغلق النافذة ولا تبدأ التنزيل', (tester) async {
    final c = _FakeChecker(const AppUpdate());
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-later')));
    await tester.pumpAndSettle();
    expect(c.started, isEmpty);
    expect(find.text('الرئيسية'), findsOneWidget);
  });

  testWidgets('لا تحديث: لا نافذة ولا إزعاج', (tester) async {
    final c = _FakeChecker(null);
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    expect(c.checks, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  test('مقارنة الإصدارات: 1.10.0 أحدث من 1.9.2، والمتساويان ليسا تحديثاً', () {
    expect(StoreUpdateChecker.isNewer('1.10.0', '1.9.2'), isTrue);
    expect(StoreUpdateChecker.isNewer('1.1.1', '1.1.0'), isTrue);
    expect(StoreUpdateChecker.isNewer('1.1.0', '1.1.0'), isFalse);
    expect(StoreUpdateChecker.isNewer('1.0.9', '1.1.0'), isFalse);
  });
}
