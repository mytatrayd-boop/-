import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ports/speed_store.dart';

class PrefsSpeedStore implements SpeedStore {
  PrefsSpeedStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;

  static const key = 'playback_speed';

  @override
  Future<double?> load() => _prefs.getDouble(key);

  @override
  Future<void> save(double speed) => _prefs.setDouble(key, speed);
}
