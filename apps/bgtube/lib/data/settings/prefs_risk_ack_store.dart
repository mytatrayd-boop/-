import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ports/risk_ack_store.dart';

/// ليس سرّاً، فيكفي shared_preferences.
class PrefsRiskAckStore implements RiskAckStore {
  PrefsRiskAckStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;

  static const key = 'risk_ack_d10';

  @override
  Future<bool> isAcknowledged() async => await _prefs.getBool(key) ?? false;

  @override
  Future<void> acknowledge() => _prefs.setBool(key, true);
}
