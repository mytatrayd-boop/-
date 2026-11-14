/// إعدادات وقت البناء. المفتاح نفسه لا يصل إلى Dart؛ فقط علم وجوده
/// (`--dart-define-from-file=.env`). بلا مفتاح يعمل التطبيق بخريطة بديلة.
class Env {
  const Env._();

  static const String _mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get hasMapsKey => _mapsKey.isNotEmpty;
}
