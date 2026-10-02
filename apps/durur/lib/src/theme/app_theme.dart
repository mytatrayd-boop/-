import 'package:flutter/material.dart';

/// ألوان DESIGN §2 للوضعين، تُقرأ في الواجهة بـ `DururColors.of(context)`.
@immutable
class DururColors extends ThemeExtension<DururColors> {
  const DururColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.primary,
    required this.onPrimary,
    required this.sea,
    required this.goldText,
    required this.goldDeco,
    required this.starMark,
    required this.line,
    required this.outline,
    required this.error,
    required this.warningBg,
    required this.onWarning,
    required this.seasons,
    required this.onSeason,
    required this.seasonTint,
  });

  /// الوضع الفاتح «رمل النهار» (DESIGN 2.1، 2.3).
  static const light = DururColors(
    background: Color(0xFFFAF5EA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF2EADB),
    ink: Color(0xFF2B2118),
    inkSoft: Color(0xFF5E5246),
    primary: Color(0xFF1B2A4A),
    onPrimary: Color(0xFFFFFFFF),
    sea: Color(0xFF0F6E6E),
    goldText: Color(0xFF7A5C00),
    goldDeco: Color(0xFFD4A82A),
    starMark: Color(0xFF7A5C00),
    line: Color(0xFFE3D8C3),
    outline: Color(0xFF8A7C69),
    error: Color(0xFFB3261E),
    warningBg: Color(0xFFFFE9B3),
    onWarning: Color(0xFF2B2118),
    seasons: {
      'safari': Color(0xFF8A4B12),
      'shita': Color(0xFF1F4E79),
      'saif': Color(0xFF2E6B34),
      'qaiz': Color(0xFFA3361F),
    },
    onSeason: Color(0xFFFFFFFF),
    seasonTint: 0.16,
  );

  /// الوضع الداكن «سماء الليل» (DESIGN 2.2، 2.3).
  static const dark = DururColors(
    background: Color(0xFF0E1626),
    surface: Color(0xFF17223A),
    surfaceAlt: Color(0xFF1F2C48),
    ink: Color(0xFFF3ECDD),
    inkSoft: Color(0xFFB9B0A0),
    primary: Color(0xFFE9C46A),
    onPrimary: Color(0xFF0E1626),
    sea: Color(0xFF5CC2C2),
    goldText: Color(0xFFE9C46A),
    goldDeco: Color(0xFFD4A82A),
    starMark: Color(0xFFD4A82A),
    line: Color(0xFF2A3756),
    outline: Color(0xFF7D8BA8),
    error: Color(0xFFFFB4AB),
    warningBg: Color(0xFF5A4300),
    onWarning: Color(0xFFFFF4D6),
    seasons: {
      'safari': Color(0xFFE8A55C),
      'shita': Color(0xFF8DB8E8),
      'saif': Color(0xFF8FCB8A),
      'qaiz': Color(0xFFF08A6C),
    },
    onSeason: Color(0xFF0E1626),
    seasonTint: 0.24,
  );

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkSoft;
  final Color primary;
  final Color onPrimary;
  final Color sea;
  final Color goldText;
  final Color goldDeco;

  /// نجوم حلقة النجوم: gold-deco لا يصلح على الرمل وحده (DESIGN 2.1)،
  /// فيُستخدم gold-text في الفاتح.
  final Color starMark;
  final Color line;
  final Color outline;
  final Color error;
  final Color warningBg;
  final Color onWarning;

  /// لون كل موسم كبير بمعرّف عنصره في items.json (DESIGN 2.3).
  final Map<String, Color> seasons;

  /// النص فوق لون الموسم المصمت (أبيض في الفاتح، كحلي في الداكن).
  final Color onSeason;

  /// شفافية ظل الموسم خلف الدرور (16% فاتح، 24% داكن).
  final double seasonTint;

  /// لون الموسم الكبير [itemId]، أو `outline` لمعرّف غير معروف.
  Color season(String? itemId) => seasons[itemId] ?? outline;

  static DururColors of(BuildContext context) =>
      Theme.of(context).extension<DururColors>() ?? light;

  @override
  DururColors copyWith() => this;

  @override
  DururColors lerp(DururColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// أسماء عائلات الخطوط المضمّنة (DESIGN §3).
abstract final class DururFonts {
  static const display = 'ReemKufi';
  static const body = 'IBMPlexSansArabic';

  /// المثل الشعبي (DESIGN §3، `proverb`)، والمائل العربي الوحيد المسموح.
  static const proverb = 'Amiri';
}

/// ثيم التطبيق (DESIGN §2–§5): ألوان الوضعين، والخطوط، وسلّم الأحجام.
ThemeData buildDururTheme(Brightness brightness) {
  final c = brightness == Brightness.light
      ? DururColors.light
      : DururColors.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.sea,
    onSecondary: c.onPrimary,
    error: c.error,
    onError: brightness == Brightness.light ? Colors.white : c.background,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkSoft,
    surfaceContainerHighest: c.surfaceAlt,
    surfaceContainerHigh: c.surfaceAlt,
    surfaceContainer: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainerLowest: c.surface,
    outline: c.outline,
    outlineVariant: c.line,
  );

  // Reem Kufi خط متغيّر: الوزن عبر محور wght.
  TextStyle kufi(double size, double height, int weight) => TextStyle(
    fontFamily: DururFonts.display,
    fontSize: size,
    height: height / size,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    color: c.ink,
  );
  TextStyle plex(
    double size,
    double height,
    FontWeight weight, [
    Color? color,
  ]) => TextStyle(
    fontFamily: DururFonts.body,
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    color: color ?? c.ink,
  );

  // سلّم الأحجام (DESIGN §3): display، h1، h2، h3، body-l، body، label، caption.
  final textTheme = TextTheme(
    displaySmall: kufi(34, 48, 700),
    headlineMedium: kufi(26, 38, 700),
    headlineSmall: kufi(26, 38, 700),
    titleLarge: kufi(21, 32, 500),
    titleMedium: plex(18, 28, FontWeight.w600),
    titleSmall: plex(15, 22, FontWeight.w600),
    bodyLarge: plex(17, 28, FontWeight.w400),
    bodyMedium: plex(15, 25, FontWeight.w400),
    bodySmall: plex(13, 20, FontWeight.w500, c.inkSoft),
    labelLarge: plex(15, 22, FontWeight.w600),
    labelMedium: plex(13, 20, FontWeight.w600),
    labelSmall: plex(11, 16, FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: DururFonts.body,
    textTheme: textTheme,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 56,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: brightness == Brightness.light ? 1 : 0,
      shadowColor: const Color(0x142B2118),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: brightness == Brightness.light
            ? BorderSide(color: c.line)
            : BorderSide.none,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: c.outline),
      labelStyle: textTheme.labelLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        side: BorderSide(color: c.primary, width: 1.5),
        foregroundColor: c.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: c.sea,
        textStyle: textTheme.labelLarge,
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1),
  );
}
