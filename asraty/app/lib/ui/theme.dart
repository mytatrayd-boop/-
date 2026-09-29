import 'package:flutter/material.dart';

/// Design tokens from design/prototype.html (:root and the dark overrides).
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.brandInk,
    required this.mintBg,
    required this.redBg,
    required this.wait,
    required this.waitInk,
  });

  static const brand = Color(0xFF2F6158);
  static const sun = Color(0xFFD9B26A);
  static const sunDeep = Color(0xFFB8893A);
  static const mint = Color(0xFF2E9E78);
  static const red = Color(0xFFC8424A);
  static const onSun = Color(0xFF2B2410);

  final Color bg, card, ink, muted, line, brandInk, mintBg, redBg, wait, waitInk;

  static const light = Palette(
    bg: Color(0xFFF6F2E8), card: Color(0xFFFFFFFF), ink: Color(0xFF1E302C), muted: Color(0xFF66736F),
    line: Color(0xFFE7E1D2), brandInk: Color(0xFF2F6158), mintBg: Color(0xFFE3F4EC), redBg: Color(0xFFFBE9EA),
    wait: Color(0xFFFBF1DA), waitInk: Color(0xFF8A6414),
  );

  static const dark = Palette(
    bg: Color(0xFF111A18), card: Color(0xFF1A2522), ink: Color(0xFFEEF2EF), muted: Color(0xFFA5B3AE),
    line: Color(0xFF2A3833), brandInk: Color(0xFF8FD1BE), mintBg: Color(0xFF123A30), redBg: Color(0xFF3A1A22),
    wait: Color(0xFF3A3218), waitInk: Color(0xFFF0CF86),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < .5 ? this : (other as Palette? ?? this);
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

const bodyFont = 'Tajawal';
const headFont = 'BalooBhaijaan2';

TextStyle heading(BuildContext c, {double size = 22}) => TextStyle(
      fontFamily: headFont,
      fontSize: size,
      fontWeight: FontWeight.w800,
      fontVariations: const [FontVariation('wght', 800)],
      height: 1.2,
      color: c.pal.ink,
    );

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: Palette.brand, brightness: b).copyWith(
    primary: Palette.brand,
    onPrimary: Colors.white,
    secondary: Palette.sun,
    surface: p.card,
    onSurface: p.ink,
    error: Palette.red,
  );
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: bodyFont,
    extensions: [p],
    textTheme: ThemeData(brightness: b).textTheme.apply(fontFamily: bodyFont, bodyColor: p.ink, displayColor: p.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border(p.line),
      enabledBorder: border(p.line),
      focusedBorder: border(Palette.sun, 2),
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted, fontSize: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.brand,
      contentTextStyle: const TextStyle(fontFamily: bodyFont, color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.card),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.brand : null),
    ),
  );
}
