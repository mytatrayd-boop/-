import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// لون صفحة القارئ (DESIGN §1.3، §9.2).
enum ReaderPageTheme { light, paper, dark }

/// مستويات خط القراءة (DESIGN §2.2): ستة، والافتراضي الثالث.
const readerFontSizes = <double>[18, 20, 22, 25, 28, 32];
const defaultReaderLevel = 3;
const maxReaderFontSize = 64.0;

/// الحجم الفعلي = حجم المستوى × مقياس خط النظام، بحد أعلى 64.
double readerFontSize(int level, TextScaler systemScaler) {
  final base =
      readerFontSizes[(level - 1).clamp(0, readerFontSizes.length - 1)];
  return systemScaler.scale(base).clamp(0, maxReaderFontSize).toDouble();
}

class ReaderSettings {
  const ReaderSettings({this.level = defaultReaderLevel, this.pageTheme});

  /// 1..6.
  final int level;

  /// null = يتبع ثيم التطبيق (فاتح أو داكن).
  final ReaderPageTheme? pageTheme;

  ReaderPageTheme effectiveTheme(Brightness appBrightness) =>
      pageTheme ??
      (appBrightness == Brightness.dark
          ? ReaderPageTheme.dark
          : ReaderPageTheme.light);
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

final readerSettingsProvider =
    AsyncNotifierProvider<ReaderSettingsController, ReaderSettings>(
      ReaderSettingsController.new,
    );

class ReaderSettingsController extends AsyncNotifier<ReaderSettings> {
  static const levelKey = 'reader.font_level';
  static const themeKey = 'reader.page_theme';

  @override
  Future<ReaderSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final level = prefs.getInt(levelKey) ?? defaultReaderLevel;
    final themeName = prefs.getString(themeKey);
    return ReaderSettings(
      level: level.clamp(1, readerFontSizes.length),
      pageTheme: ReaderPageTheme.values
          .where((t) => t.name == themeName)
          .firstOrNull,
    );
  }

  ReaderSettings get _current => state.value ?? const ReaderSettings();

  Future<void> setLevel(int level) async {
    final next = level.clamp(1, readerFontSizes.length);
    if (next == _current.level) return;
    state = AsyncData(
      ReaderSettings(level: next, pageTheme: _current.pageTheme),
    );
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt(levelKey, next);
  }

  Future<void> setPageTheme(ReaderPageTheme theme) async {
    state = AsyncData(ReaderSettings(level: _current.level, pageTheme: theme));
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(themeKey, theme.name);
  }
}

/// ألوان منطقة القراءة وشريطيها لكل لون صفحة (DESIGN §1.1–1.3).
class ReaderPalette {
  const ReaderPalette({
    required this.background,
    required this.bars,
    required this.text,
    required this.secondary,
    required this.rubric,
    required this.selected,
    required this.searchHighlight,
    required this.brightness,
  });

  final Color background;
  final Color bars;
  final Color text;
  final Color secondary;
  final Color rubric;

  /// الفقرة المختارة (الضغط المطوّل) أو المفتوحة من رابط.
  final Color selected;

  /// خلفية كلمة البحث داخل الفقرة المفتوحة من نتيجة (مع خط سفلي).
  final Color searchHighlight;
  final Brightness brightness;

  static const light = ReaderPalette(
    background: Color(0xFFFBF8F1),
    bars: Color(0xFFFFFFFF),
    text: Color(0xFF1F1A14),
    secondary: Color(0xFF5C5247),
    rubric: Color(0xFF8A3B1F),
    selected: Color(0xFFE6F0EC),
    searchHighlight: Color(0xFFFFE08A),
    brightness: Brightness.light,
  );

  static const paper = ReaderPalette(
    background: Color(0xFFF3E9D2),
    bars: Color(0xFFEADDC0),
    text: Color(0xFF3B2F20),
    secondary: Color(0xFF6A5638),
    rubric: Color(0xFF7A3E1D),
    selected: Color(0xFFE6D3A8),
    searchHighlight: Color(0xFFF7C948),
    brightness: Brightness.light,
  );

  static const dark = ReaderPalette(
    background: Color(0xFF15130F),
    bars: Color(0xFF1F1C17),
    text: Color(0xFFEDE6D8),
    secondary: Color(0xFFB8AE9E),
    rubric: Color(0xFFE59A78),
    selected: Color(0xFF1F3A33),
    searchHighlight: Color(0xFF5A4A12),
    brightness: Brightness.dark,
  );

  static ReaderPalette of(ReaderPageTheme theme) => switch (theme) {
    ReaderPageTheme.light => light,
    ReaderPageTheme.paper => paper,
    ReaderPageTheme.dark => dark,
  };
}
