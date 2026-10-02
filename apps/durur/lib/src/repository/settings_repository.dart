import 'package:shared_preferences/shared_preferences.dart';

/// فشل حفظ الإعدادات على الجهاز (نادر).
class SettingsSaveException implements Exception {
  const SettingsSaveException(this.key);

  final String key;

  @override
  String toString() => 'SettingsSaveException: تعذّر حفظ "$key".';
}

/// إعدادات المستخدم المحفوظة على الجهاز فقط (ARCHITECTURE §12).
///
/// يُحفظ **معرّف المدينة فقط**، ولا تُحفظ أي إحداثيات (D11).
class SettingsRepository {
  const SettingsRepository(this._prefs);

  static const cityIdKey = 'cityId';

  final SharedPreferences _prefs;

  String? get cityId => _prefs.getString(cityIdKey);

  Future<void> saveCityId(String cityId) async {
    final ok = await _prefs.setString(cityIdKey, cityId);
    if (!ok) throw const SettingsSaveException(cityIdKey);
  }
}
