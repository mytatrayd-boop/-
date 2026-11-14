import 'package:material_ui/material_ui.dart';

/// ألوان DESIGN.md القسم 2 (الداكن افتراضي).
class AppColors {
  const AppColors._();
  static const ink = Color(0xFF0E1316);
  static const surface1 = Color(0xFF182026);
  static const surface2 = Color(0xFF222C33);
  static const outline = Color(0xFF36424A);
  static const textPrimary = Color(0xFFF3F6F8);
  static const textSecondary = Color(0xFFB4C0C8);
  static const amber = Color(0xFFF5A524);
  static const emerald = Color(0xFF2FBF9B);
  static const recordRed = Color(0xFFE5484D);
  static const warning = Color(0xFFFFC857);
  static const error = Color(0xFFFF6B6B);
}

class AppTheme {
  const AppTheme._();

  static const _scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.amber,
    onPrimary: AppColors.ink,
    secondary: AppColors.emerald,
    onSecondary: AppColors.ink,
    error: AppColors.error,
    onError: AppColors.ink,
    surface: AppColors.ink,
    onSurface: AppColors.textPrimary,
    surfaceContainer: AppColors.surface1,
    surfaceContainerHighest: AppColors.surface2,
    outline: AppColors.outline,
    onSurfaceVariant: AppColors.textSecondary,
  );

  static const fontFamily = 'IBMPlexSansArabic';

  static TextStyle _s(double size, FontWeight w, double h, Color c) =>
      TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: w, height: h, color: c);

  static ThemeData dark() {
    const p = AppColors.textPrimary;
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: _scheme,
      scaffoldBackgroundColor: AppColors.ink,
      canvasColor: AppColors.ink,
      dividerColor: AppColors.outline,
      textTheme: TextTheme(
        headlineSmall: _s(24, FontWeight.w700, 1.4, p), // عنوان شاشة
        titleMedium: _s(18, FontWeight.w600, 1.5, p), // عنوان بطاقة
        bodyLarge: _s(16, FontWeight.w400, 1.6, p), // نص
        bodyMedium: _s(16, FontWeight.w400, 1.6, p),
        bodySmall: _s(14, FontWeight.w400, 1.5, AppColors.textSecondary),
        labelLarge: _s(18, FontWeight.w600, 1.2, p), // الأزرار
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _s(18, FontWeight.w600, 1.2, AppColors.ink),
        ),
      ),
    );
  }
}
