import 'package:flutter/material.dart';

/// ألوان DESIGN §1.1 (ColorScheme يدوي، لا fromSeed).
const _light = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF6F4E37),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFEAD9C6),
  onPrimaryContainer: Color(0xFF2B1D14),
  secondary: Color(0xFFB87628),
  onSecondary: Color(0xFFFFFFFF),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  surface: Color(0xFFFAF6F0),
  onSurface: Color(0xFF2B1D14),
  onSurfaceVariant: Color(0xFF6B5A4E),
  surfaceContainer: Color(0xFFFFFFFF),
  surfaceContainerHigh: Color(0xFFF2E9DC),
  outline: Color(0xFF8C7563),
  outlineVariant: Color(0xFFE3D6C6),
);

const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFD9B48F),
  onPrimary: Color(0xFF2B1D14),
  primaryContainer: Color(0xFF4A3226),
  onPrimaryContainer: Color(0xFFF3EAE0),
  secondary: Color(0xFFE0A458),
  onSecondary: Color(0xFF2B1D14),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  errorContainer: Color(0xFF8C1D18),
  onErrorContainer: Color(0xFFF9DEDC),
  surface: Color(0xFF1A1210),
  onSurface: Color(0xFFF3EAE0),
  onSurfaceVariant: Color(0xFFBFAE9F),
  surfaceContainer: Color(0xFF241A16),
  surfaceContainerHigh: Color(0xFF2F231D),
  outline: Color(0xFF8F7D70),
  outlineVariant: Color(0xFF3A2C25),
);

/// ألوان شريط نسخة العرض (DESIGN §1.1): ثابتة في الثيمين عمداً.
const demoBannerBackground = Color(0xFFFFE08A);
const demoBannerForeground = Color(0xFF3D2A00);

ThemeData buildTheme(Brightness brightness) {
  final scheme = brightness == Brightness.light ? _light : _dark;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: scheme.surface,
  );
  final text = base.textTheme;
  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: text.displayLarge?.copyWith(fontSize: 56, fontWeight: FontWeight.w700),
      headlineMedium: text.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      labelMedium: text.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Tajawal'),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: brightness == Brightness.light
            ? BorderSide(color: scheme.outlineVariant)
            : BorderSide.none,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// لون النجاح (امتداد DESIGN §1.1): «تم الحفظ»، «تم تحديد الموقع».
Color successColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF2E7D32)
        : const Color(0xFF81C995);
