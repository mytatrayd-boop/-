import 'package:shared_preferences/shared_preferences.dart';

import '../formatting/digits.dart';

/// فشل حفظ الإعدادات على الجهاز (نادر).
class SettingsSaveException implements Exception {
  const SettingsSaveException(this.key);

  final String key;

  @override
  String toString() => 'SettingsSaveException: تعذّر حفظ "$key".';
}

/// السمة المختارة (DESIGN 8.7): حسب الجهاز (الافتراضي)، فاتح، داكن.
enum ThemeChoice {
  system('system'),
  light('light'),
  dark('dark');

  const ThemeChoice(this.code);

  final String code;

  static ThemeChoice parse(String? code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return system;
  }
}

/// إعدادات المستخدم المحفوظة على الجهاز فقط (ARCHITECTURE §12).
///
/// يُحفظ **معرّف المدينة فقط**، ولا تُحفظ أي إحداثيات (D11)؛ ومعه مفتاحا
/// التنبيهات وانتهاء الإعداد الأولي والسمة والأرقام (الميزة 8)، ومفتاح تحديث
/// البيانات (الميزة 11ب). القيم
/// الافتراضية لا تُكتب على الجهاز؛ يُحفظ ما يغيّره المستخدم فقط.
class SettingsRepository {
  const SettingsRepository(this._prefs);

  static const cityIdKey = 'cityId';

  /// انتهى الإعداد الأولي (بعد شرح التنبيهات، DESIGN 8.2 د).
  static const onboardingDoneKey = 'onboardingDone';

  /// مفتاح «المواسم المهمة» (مفعّل افتراضياً، SPEC 8 معيار 1).
  static const notifyImportantKey = 'notifyImportant';

  /// مفتاح «بداية كل دَرّ» (مطفأ افتراضياً).
  static const notifyDarKey = 'notifyDar';

  /// مفتاح «تحديث البيانات تلقائياً» (مفعّل افتراضياً، D21، ARCHITECTURE §16.4).
  static const autoUpdateKey = 'data.autoUpdate';

  static const themeKey = 'theme';
  static const digitsKey = 'digits';

  final SharedPreferences _prefs;

  String? get cityId => _prefs.getString(cityIdKey);
  bool get onboardingDone => _prefs.getBool(onboardingDoneKey) ?? false;
  bool get notifyImportant => _prefs.getBool(notifyImportantKey) ?? true;
  bool get notifyDar => _prefs.getBool(notifyDarKey) ?? false;
  bool get autoUpdate => _prefs.getBool(autoUpdateKey) ?? true;
  ThemeChoice get theme => ThemeChoice.parse(_prefs.getString(themeKey));
  DigitStyle get digits => DigitStyle.parse(_prefs.getString(digitsKey));

  Future<void> saveCityId(String cityId) => _setString(cityIdKey, cityId);

  Future<void> saveOnboardingDone() => _setBool(onboardingDoneKey, true);

  Future<void> saveNotifyImportant(bool on) => _setBool(notifyImportantKey, on);

  Future<void> saveNotifyDar(bool on) => _setBool(notifyDarKey, on);

  Future<void> saveAutoUpdate(bool on) => _setBool(autoUpdateKey, on);

  Future<void> saveTheme(ThemeChoice theme) => _setString(themeKey, theme.code);

  Future<void> saveDigits(DigitStyle digits) =>
      _setString(digitsKey, digits.code);

  Future<void> _setString(String key, String value) async {
    final ok = await _prefs.setString(key, value);
    if (!ok) throw SettingsSaveException(key);
  }

  Future<void> _setBool(String key, bool value) async {
    final ok = await _prefs.setBool(key, value);
    if (!ok) throw SettingsSaveException(key);
  }
}
