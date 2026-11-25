import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ports/locale_store.dart';

class PrefsLocaleStore implements LocaleStore {
  PrefsLocaleStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;

  static const key = 'language_code';

  @override
  Future<String?> load() => _prefs.getString(key);

  @override
  Future<void> save(String languageCode) => _prefs.setString(key, languageCode);
}
