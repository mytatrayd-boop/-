/// سمات لون الودجت (الميزة ٣ج). اللون المميز للصلاة واليوم، والخلفية تتأثر بشريط الشفافية.
/// القيم ARGB، وتُكتب في الجدول (`theme`) لتطبقها المعاينة والودجت كما هي.
enum WidgetTheme {
  /// أسود (الافتراضي، تصميم المالك ٣) بتمييز ذهبي.
  black(0xFFD6AA5C, 0xFF000000),
  gold(0xFFD6AA5C, 0xFF2A241D),
  green(0xFF78BE96, 0xFF212A24),
  blue(0xFF7FB2E5, 0xFF1C2430),
  purple(0xFFB39DDB, 0xFF251F30),
  pink(0xFFEE9AB8, 0xFF2E1F26),
  gray(0xFFBDBDBD, 0xFF232323),

  /// ألوان النظام (Material You، أندرويد ١٢+). ألوانها هنا احتياطية = الذهبي،
  /// والودجت تأخذ ألوان النظام بنفسها إن توفرت.
  system(0xFFD6AA5C, 0xFF2A241D);

  const WidgetTheme(this.accent, this.background);

  final int accent;
  final int background;

  static const fallback = WidgetTheme.black;

  static WidgetTheme byName(String? name) =>
      WidgetTheme.values.firstWhere((t) => t.name == name, orElse: () => fallback);
}

/// ألوان النظام كما يقرؤها أندرويد ١٢+ (system_accent1_200 وsystem_neutral1_900).
typedef SystemColors = ({int accent, int background});

/// اللونان الفعليان: ألوان النظام للسمة [WidgetTheme.system] إن توفرت، وإلا ألوان السمة.
({int accent, int background}) themeColors(WidgetTheme t, SystemColors? system) =>
    t == WidgetTheme.system && system != null
        ? system
        : (accent: t.accent, background: t.background);

/// ما يحمله الجدول للسمة.
Map<String, Object> themeScheduleJson(WidgetTheme t) =>
    {'id': t.name, 'accent': t.accent, 'background': t.background};
