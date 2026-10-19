import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/main.dart';
import 'package:lamha/src/app/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('خطأ التحميل يظهر بتفاصيله وزر إعادة المحاولة، لا دوّامة', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        engineDataProvider.overrideWith((ref) async => throw StateError('boom')),
      ],
      child: const LamhaApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('تعذّر تحميل الإعدادات'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.byKey(const Key('retry-button')), findsOneWidget);
  });
}
