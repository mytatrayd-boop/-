import 'package:flutter/material.dart';

import 'app_colors.dart';

/// الثيم الفاتح والداكن وفق DESIGN.md (الخط، الأحجام، الزوايا، الأزرار).
class AppTheme {
  const AppTheme._();

  static const fontFamily = 'IBMPlexSansArabic';
  static const double cardRadius = 16;
  static const double buttonRadius = 14;
  static const double buttonHeight = 52;

  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.accent,
      onSecondary: c.onPrimary,
      error: c.error,
      onError: c.onPrimary,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkSecondary,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.border,
      outlineVariant: c.border,
    );

    TextStyle style(double size, FontWeight weight, {double? height, Color? color}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? c.ink,
        );

    final textTheme = TextTheme(
      displayLarge: style(48, FontWeight.w700),
      headlineMedium: style(24, FontWeight.w700),
      titleMedium: style(18, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400, height: 1.6),
      bodyMedium: style(16, FontWeight.w400, height: 1.6),
      bodySmall: style(14, FontWeight.w400, height: 1.6, color: c.inkSecondary),
      labelLarge: style(16, FontWeight.w600),
      labelMedium: style(14, FontWeight.w600),
      labelSmall: style(14, FontWeight.w400, color: c.inkSecondary),
    );

    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: c.bg,
      textTheme: textTheme,
      dividerColor: c.border,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: c.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, buttonHeight),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, buttonHeight),
          shape: buttonShape,
          side: BorderSide(color: c.primary, width: 1.5),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.surfaceAlt,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? c.primary : c.inkSecondary,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: c.border),
        labelStyle: textTheme.labelMedium,
      ),
    );
  }
}
