import 'dart:io';
import 'dart:math';

import 'package:bgtube/core/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// نسبة التباين وفق WCAG 2.x (الإضاءة النسبية sRGB).
double contrast(Color a, Color b) {
  double lin(double c) => c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  final la = lum(a), lb = lum(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('contrast helper sanity (black/white = 21, same = 1)', () {
    expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrast(AppColors.primary, AppColors.primary), closeTo(1, 0.001));
  });

  // (نص، خلفية، الحد الأدنى، وصف)
  final pairs = <(Color, Color, double, String)>[
    (AppColors.textPrimary, AppColors.background, 4.5, 'primary text / background'),
    (AppColors.textPrimary, AppColors.surface, 4.5, 'primary text / surface'),
    (AppColors.textPrimary, AppColors.surfaceHigh, 4.5, 'primary text / surface-high'),
    (AppColors.textSecondary, AppColors.background, 4.5, 'secondary text / background'),
    (AppColors.textSecondary, AppColors.surface, 4.5, 'secondary text / surface'),
    (AppColors.textSecondary, AppColors.surfaceHigh, 4.5, 'secondary text / surface-high'),
    (AppColors.background, AppColors.primary, 4.5, 'text on primary button'),
    (AppColors.primary, AppColors.background, 3.0, 'primary icon / background'),
    (AppColors.primary, AppColors.surface, 3.0, 'primary icon / surface'),
    (AppColors.success, AppColors.background, 4.5, 'success / background'),
    (AppColors.success, AppColors.surface, 4.5, 'success / surface'),
    (AppColors.warning, AppColors.background, 4.5, 'warning / background'),
    (AppColors.warning, AppColors.surface, 4.5, 'warning / surface'),
    (AppColors.error, AppColors.background, 4.5, 'error / background'),
    (AppColors.error, AppColors.surface, 4.5, 'error / surface'),
    (AppColors.error, AppColors.surfaceHigh, 4.5, 'error / surface-high'),
    // الحد الفاصل مكوّن غير نصي: 3:1 مطلوب فقط إن كان وحده يحدد حدود عنصر تفاعلي.
    (AppColors.divider, AppColors.background, 1.0, 'divider / background (informational)'),
  ];

  for (final (fg, bg, min, name) in pairs) {
    test('contrast >= $min : $name', () {
      final r = contrast(fg, bg);
      // ignore: avoid_print
      print('CONTRAST ${r.toStringAsFixed(2)}:1  ($name, needs $min)');
      expect(r, greaterThanOrEqualTo(min));
    });
  }

  test('fonts: Cairo and Tajawal are declared in pubspec and the files exist', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final f in [
      'assets/fonts/Cairo.ttf',
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Medium.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
    ]) {
      expect(pubspec, contains(f));
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    final theme = buildDarkTheme();
    expect(theme.textTheme.bodyMedium!.fontFamily, appFontFamily);
    expect(theme.textTheme.bodyMedium!.fontFamilyFallback, appFontFallback);
    expect(theme.brightness, Brightness.dark);
  });

  test('type scale follows DESIGN.md and never goes below 12', () {
    final t = buildDarkTheme().textTheme;
    expect(t.titleLarge!.fontSize, 22);
    expect(t.titleLarge!.fontWeight, FontWeight.w700);
    expect(t.titleMedium!.fontSize, 16);
    expect(t.bodyMedium!.fontSize, 14);
    for (final s in [t.bodySmall, t.labelMedium, t.labelSmall]) {
      expect(s!.fontSize, greaterThanOrEqualTo(12));
    }
    expect(t.bodyMedium!.height, 1.5);
  });
}
