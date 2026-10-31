import 'package:flutter/material.dart';

/// ألوان DESIGN.md §1. الوضع الداكن: القيم غير المحددة في التصميم مسجلة في DECISIONS.md.
class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSecondary,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.border,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkSecondary;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color border;

  static const light = AppColors(
    bg: Color(0xFFFBF6EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1E7D8),
    ink: Color(0xFF2B1B12),
    inkSecondary: Color(0xFF6A5646),
    primary: Color(0xFF6B3F26),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFB8742F),
    success: Color(0xFF2F6B4F),
    warning: Color(0xFF8A5A00),
    error: Color(0xFFB3261E),
    border: Color(0xFFDCCDB9),
  );

  static const dark = AppColors(
    bg: Color(0xFF1A110C),
    surface: Color(0xFF271A13),
    surfaceAlt: Color(0xFF33231A),
    ink: Color(0xFFF5EBDD),
    inkSecondary: Color(0xFFC9B8A4),
    primary: Color(0xFFE0A066),
    onPrimary: Color(0xFF1A110C),
    accent: Color(0xFFB8742F),
    success: Color(0xFF6FCF9F),
    warning: Color(0xFFE8B04A),
    error: Color(0xFFFF8A80),
    border: Color(0xFF4A3628),
  );
}
