import 'package:material_ui/material_ui.dart';

/// ثيم داكن وفق DESIGN.md.
abstract final class AppColors {
  static const background = Color(0xFF0E1014);
  static const surface = Color(0xFF181B22);
  static const surfaceHigh = Color(0xFF222630);
  static const divider = Color(0xFF2E3340);
  static const textPrimary = Color(0xFFF2F4F8);
  static const textSecondary = Color(0xFFA9B0BC);
  static const primary = Color(0xFFFF6B5E);
  static const error = Color(0xFFFF8A80);
}

ThemeData buildDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.background,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.error,
    outline: AppColors.divider,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
