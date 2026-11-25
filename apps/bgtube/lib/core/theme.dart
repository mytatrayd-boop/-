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
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFFF8A80);
}

/// Cairo مضمّن في assets (يعمل دون إنترنت)، وTajawal بديله.
const appFontFamily = 'Cairo';
const appFontFallback = ['Tajawal'];

TextTheme _buildTextTheme() {
  final base = Typography.whiteMountainView.apply(
    fontFamily: appFontFamily,
    fontFamilyFallback: appFontFallback,
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );
  TextStyle? s(TextStyle? t, double size, FontWeight w, {Color? color}) =>
      t?.copyWith(fontSize: size, fontWeight: w, height: 1.5, color: color);
  return base.copyWith(
    // عنوان الشاشة 22/700
    headlineSmall: s(base.headlineSmall, 22, FontWeight.w700),
    titleLarge: s(base.titleLarge, 22, FontWeight.w700),
    // عنوان البطاقة 16/600
    titleMedium: s(base.titleMedium, 16, FontWeight.w600),
    // نص 14/400
    bodyMedium: s(base.bodyMedium, 14, FontWeight.w400),
    bodyLarge: s(base.bodyLarge, 16, FontWeight.w400),
    // ثانوي 12/400 (لا أقل من 12)
    bodySmall: s(base.bodySmall, 12, FontWeight.w400, color: AppColors.textSecondary),
    labelLarge: s(base.labelLarge, 14, FontWeight.w600),
    labelMedium: s(base.labelMedium, 12, FontWeight.w400),
    labelSmall: s(base.labelSmall, 12, FontWeight.w400),
  );
}

ThemeData buildDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.background,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    error: AppColors.error,
    outline: AppColors.divider,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    fontFamilyFallback: appFontFallback,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: _buildTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1),
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
