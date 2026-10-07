import 'package:flutter/material.dart';

/// ألوان هوية «سماء الدرور» الزجاجية (DESIGN R2.2): وضع داكن واحد (D38).
/// تُقرأ في الواجهة بـ `DururColors.of(context)`.
@immutable
class DururColors extends ThemeExtension<DururColors> {
  const DururColors({
    required this.background,
    required this.backgroundDeep,
    required this.backgroundGlow,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.primary,
    required this.onPrimary,
    required this.sea,
    required this.goldText,
    required this.goldDeco,
    required this.starMark,
    required this.agri,
    required this.line,
    required this.glassStroke,
    required this.outline,
    required this.error,
    required this.warningBg,
    required this.onWarning,
    required this.seasons,
    required this.onSeason,
    required this.seasonTint,
  });

  /// الوضع الوحيد (DESIGN R2.2، R2.11)، بلوحة R3.1-14 التركوازية.
  static const night = DururColors(
    background: Color(0xFF0A2230),
    backgroundDeep: Color(0xFF061620),
    backgroundGlow: Color(0xFF11384A),
    surface: Color(0xFF16303C),
    surfaceAlt: Color(0xFF2E4A57),
    ink: Color(0xFFEAF6FA),
    inkSoft: Color(0xFFA9C3D1),
    inkMuted: Color(0xFF7F9BB0),
    primary: Color(0xFF5FE3F0),
    onPrimary: Color(0xFF06101F),
    sea: Color(0xFF5FE3F0),
    goldText: Color(0xFFF2C66D),
    goldDeco: Color(0xFFF2C66D),
    starMark: Color(0xFFF2C66D),
    agri: Color(0xFF8FE0A8),
    line: Color(0x2E7FE9F3),
    glassStroke: Color(0x597FE9F3),
    outline: Color(0xFF7F9BB0),
    error: Color(0xFFFFB4AB),
    warningBg: Color(0xFF5A4300),
    onWarning: Color(0xFFFFF4D6),
    seasons: {
      'saif': Color(0xFFB5D47A),
      'qaiz': Color(0xFFF2A65A),
      'safari': Color(0xFFE3A6D8),
      'shita': Color(0xFF8CC8FF),
    },
    onSeason: Color(0xFFEAF6FA),
    seasonTint: 0.30,
  );

  /// `bg`: الخلفية الأساسية.
  final Color background;

  /// `bg-deep`: أسفل التدرّج، والنص فوق `cyan`.
  final Color backgroundDeep;

  /// `bg-glow`: أفتح نقطة في التدرّج خلف الدائرة (سقف لا يُتجاوز).
  final Color backgroundGlow;

  /// `surface`: البطاقة الزجاجية بعد التركيب فوق `bg`.
  final Color surface;

  /// `surface-selected`: التبويب والشريحة المختاران.
  final Color surfaceAlt;
  final Color ink;
  final Color inkSoft;

  /// `ink-muted`: على `bg` و`surface` فقط (ممنوع فوق `bg-glow`).
  final Color inkMuted;

  /// `cyan`: الحدود، التوهج، المؤشر، أسماء الأشهر، الأزرار.
  final Color primary;

  /// النص فوق `cyan` (`bg-deep`).
  final Color onPrimary;

  /// الروابط (`cyan`).
  final Color sea;

  /// `gold`: «اليوم»، النجم الطالع، رأس المؤشر.
  final Color goldText;
  final Color goldDeco;
  final Color starMark;

  /// أقواس حلقة الزراعة وأيقونتها.
  final Color agri;

  /// فواصل رفيعة وخلفية شريط التقدم.
  final Color line;

  /// حد الأسطح الزجاجية وحدود الحلقات (`#7FE9F3` شفافية 35%).
  final Color glassStroke;
  final Color outline;
  final Color error;
  final Color warningBg;
  final Color onWarning;

  /// نغمة كل موسم كبير بمعرّف عنصره في items.json (DESIGN R2.2).
  final Map<String, Color> seasons;

  /// النص فوق تعبئة الموسم (30%): `ink` دائماً.
  final Color onSeason;

  /// شفافية تعبئة الموسم (30%).
  final double seasonTint;

  /// نغمة الموسم الكبير [itemId]، أو `outline` لمعرّف غير معروف.
  Color season(String? itemId) => seasons[itemId] ?? outline;

  /// اللون الدلالي لأيقونة الجو في البطاقات فقط (DESIGN R2.2): حر/شمس
  /// `gold`، برد/مطر/رطوبة/ضباب أزرق الشتاء، غبار/رياح كهرماني القيظ.
  Color weatherTone(String code) => switch (code) {
    'hot' || 'very_hot' || 'mild' => goldText,
    'cool' ||
    'cold' ||
    'very_cold' ||
    'rain' ||
    'heavy_rain' ||
    'humidity' ||
    'fog' => const Color(0xFF8CC8FF),
    'dust' || 'wind' || 'wind_strong' => const Color(0xFFF2A65A),
    _ => ink,
  };

  /// لون رمز الجو على الدائرة (DESIGN R3.1-5): حر/حر شديد `gold`، برد/مطر/
  /// رطوبة/ضباب أزرق، غبار/رياح كهرماني، والبقية `ink-soft`.
  Color dialWeatherTone(String code) => switch (code) {
    'hot' || 'very_hot' => goldText,
    'cool' ||
    'cold' ||
    'very_cold' ||
    'rain' ||
    'heavy_rain' ||
    'humidity' ||
    'fog' => const Color(0xFF8CC8FF),
    'dust' || 'wind' || 'wind_strong' => const Color(0xFFF2A65A),
    _ => inkSoft,
  };

  static DururColors of(BuildContext context) =>
      Theme.of(context).extension<DururColors>() ?? night;

  @override
  DururColors copyWith() => this;

  @override
  DururColors lerp(DururColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// أسماء عائلات الخطوط المضمّنة (DESIGN §3، D37 الخيار ٣).
abstract final class DururFonts {
  /// العناوين (`display`، `h1`، `h2`): نسخي لا يُستخدم تحت [displayMinSize].
  static const display = 'Amiri';

  /// النص والواجهة والدائرة. أوزانه 300/400/700/800 فقط (لا 500/600).
  static const body = 'Almarai';

  /// أصغر حجم لخط العناوين Amiri (`h2`، DESIGN §3).
  static const displayMinSize = 21.0;

  /// المثل الشعبي (DESIGN §3، `proverb`)، والمائل العربي الوحيد المسموح.
  static const proverb = 'Amiri';
}

/// توهج النص (DESIGN R2.3): ظل بلون النص نفسه، نصف قطر 6، شفافية 45%.
/// لأسماء الأشهر (≥ 13sp، وزن 800) ورقم العدّاد فقط.
List<Shadow> textGlow(Color color) => [
  Shadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
];

/// ثيم التطبيق (DESIGN R2): داكن فقط (D38)، والخطوط وسلّم الأحجام (§3).
ThemeData buildDururTheme() {
  const c = DururColors.night;
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    error: c.error,
    onError: c.backgroundDeep,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkSoft,
    surfaceContainerHighest: c.surfaceAlt,
    surfaceContainerHigh: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainerLowest: c.background,
    secondaryContainer: c.surfaceAlt,
    onSecondaryContainer: c.ink,
    outline: c.outline,
    outlineVariant: c.glassStroke,
  );

  // Amiri للعناوين فقط، ولا يُستخدم تحت 21sp (DESIGN §3).
  TextStyle heading(double size, double height) {
    assert(size >= DururFonts.displayMinSize);
    return TextStyle(
      fontFamily: DururFonts.display,
      fontSize: size,
      height: height / size,
      fontWeight: FontWeight.w700,
      color: c.ink,
    );
  }

  TextStyle text(
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
    // Almarai بلا 500/600: h3 و label و ring بوزن 700، و caption بوزن 400.
    displaySmall: heading(34, 48),
    headlineMedium: heading(26, 38),
    headlineSmall: heading(26, 38),
    titleLarge: heading(21, 32),
    titleMedium: text(18, 28, FontWeight.w700),
    titleSmall: text(15, 22, FontWeight.w700),
    bodyLarge: text(17, 28, FontWeight.w400),
    bodyMedium: text(15, 25, FontWeight.w400),
    bodySmall: text(13, 20, FontWeight.w400, c.inkSoft),
    labelLarge: text(15, 22, FontWeight.w700),
    labelMedium: text(13, 20, FontWeight.w700),
    labelSmall: text(11, 16, FontWeight.w700),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: DururFonts.body,
    textTheme: textTheme,
    extensions: const [c],
    iconTheme: IconThemeData(color: c.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
    ),
    // بلا ظلال سوداء؛ العمق من الشفافية والحد الزجاجي (R2.3).
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.glassStroke),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: c.glassStroke),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: c.glassStroke),
      backgroundColor: Colors.transparent,
      selectedColor: c.surfaceAlt,
      labelStyle: textTheme.labelLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceAlt,
      contentTextStyle: textTheme.bodyMedium,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
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
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.inkSoft,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.surface,
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1),
  );
}
