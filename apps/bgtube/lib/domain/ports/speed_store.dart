/// تخزين آخر سرعة مختارة (ينفّذه shared_preferences في طبقة data).
abstract interface class SpeedStore {
  Future<double?> load();
  Future<void> save(double speed);
}
