import 'package:flutter/material.dart';

/// ألوان DESIGN §1 وخطوطه §2.
abstract final class AdeebColors {
  static const goldOrnament = Color(0xFFC9A24A);
  static const coverTitle = Color(0xFFFBF8F1);
}

class AdeebExtraColors extends ThemeExtension<AdeebExtraColors> {
  const AdeebExtraColors({
    required this.surfaceAlt,
    required this.divider,
    required this.success,
    required this.warningContainer,
    required this.onWarning,
  });

  final Color surfaceAlt;
  final Color divider;
  final Color success;
  final Color warningContainer;
  final Color onWarning;

  static const light = AdeebExtraColors(
    surfaceAlt: Color(0xFFF3EEE3),
    divider: Color(0xFFE2D9C9),
    success: Color(0xFF2E6B2F),
    warningContainer: Color(0xFFFFF1D6),
    onWarning: Color(0xFF6B4A00),
  );

  static const dark = AdeebExtraColors(
    surfaceAlt: Color(0xFF2A2620),
    divider: Color(0xFF3A342B),
    success: Color(0xFF8BC48C),
    warningContainer: Color(0xFF3A2E10),
    onWarning: Color(0xFFF2D48A),
  );

  @override
  AdeebExtraColors copyWith() => this;

  @override
  AdeebExtraColors lerp(AdeebExtraColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

const uiFont = 'IBMPlexSansArabic';
const bookFont = 'Amiri';

ThemeData _theme(ColorScheme scheme, AdeebExtraColors extra) {
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: uiFont,
  );
  final text = base.textTheme;
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    extensions: [extra],
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 22,
        height: 32 / 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 26 / 16),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 22 / 14),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: text.labelMedium?.copyWith(
        fontSize: 13,
        height: 20 / 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(120, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: extra.divider),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

final lightTheme = _theme(
  const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1E5B4F),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE6F0EC),
    onPrimaryContainer: Color(0xFF1E5B4F),
    secondary: Color(0xFF7A5A12),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFFA3261C),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFBF8F1),
    onSurface: Color(0xFF1F1A14),
    onSurfaceVariant: Color(0xFF5C5247),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerHighest: Color(0xFFF3EEE3),
    outline: Color(0xFF8C8072),
    outlineVariant: Color(0xFFE2D9C9),
  ),
  AdeebExtraColors.light,
);

final darkTheme = _theme(
  const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6FC2AE),
    onPrimary: Color(0xFF0E2A24),
    primaryContainer: Color(0xFF1F3A33),
    onPrimaryContainer: Color(0xFFEDE6D8),
    secondary: Color(0xFFE0BE6E),
    onSecondary: Color(0xFF15130F),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF15130F),
    surface: Color(0xFF15130F),
    onSurface: Color(0xFFEDE6D8),
    onSurfaceVariant: Color(0xFFB8AE9E),
    surfaceContainerLowest: Color(0xFF1F1C17),
    surfaceContainerHighest: Color(0xFF2A2620),
    outline: Color(0xFF7D7466),
    outlineVariant: Color(0xFF3A342B),
  ),
  AdeebExtraColors.dark,
);

extension AdeebThemeX on BuildContext {
  AdeebExtraColors get extraColors =>
      Theme.of(this).extension<AdeebExtraColors>()!;
}
