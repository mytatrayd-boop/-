import 'package:bunn_lens/app/theme/app_colors.dart';
import 'package:bunn_lens/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الثيم الفاتح يطابق ألوان DESIGN.md', () {
    final t = AppTheme.light;
    expect(t.brightness, Brightness.light);
    expect(t.scaffoldBackgroundColor, const Color(0xFFFBF6EE));
    expect(t.colorScheme.primary, const Color(0xFF6B3F26));
    expect(t.colorScheme.onSurface, const Color(0xFF2B1B12));
    expect(t.colorScheme.error, const Color(0xFFB3261E));
  });

  test('الثيم الداكن يطابق ألوان DESIGN.md', () {
    final t = AppTheme.dark;
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, const Color(0xFF1A110C));
    expect(t.colorScheme.primary, const Color(0xFFE0A066));
    expect(t.colorScheme.onPrimary, const Color(0xFF1A110C));
    expect(t.colorScheme.surface, const Color(0xFF271A13));
  });

  test('الخط المضمّن وأحجام النص ولا نص أقل من 14', () {
    final t = AppTheme.light;
    expect(t.textTheme.bodyLarge!.fontFamily, 'IBMPlexSansArabic');
    expect(t.textTheme.displayLarge!.fontSize, 48);
    expect(t.textTheme.headlineMedium!.fontWeight, FontWeight.w700);
    for (final s in [
      t.textTheme.bodyLarge, t.textTheme.bodySmall, t.textTheme.labelLarge,
      t.textTheme.labelMedium, t.textTheme.labelSmall,
    ]) {
      expect(s!.fontSize, greaterThanOrEqualTo(14));
    }
  });

  test('تباين النص الأساسي على الخلفية 4.5:1 فأكثر في الوضعين', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final c in [AppColors.light, AppColors.dark]) {
      expect(ratio(c.ink, c.bg), greaterThanOrEqualTo(12));
      for (final fg in [c.inkSecondary, c.primary, c.success, c.warning, c.error]) {
        expect(ratio(fg, c.bg), greaterThanOrEqualTo(4.5));
      }
      expect(ratio(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('التطبيق يستخدم الثيم الداكن عند وضع النظام الداكن', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Builder(builder: (c) => Text('${Theme.of(c).brightness}')),
    ));
    expect(find.text('Brightness.dark'), findsOneWidget);
  });
}
