/// إعداد التطبيق من `--dart-define-from-file=config/app_config.json`
/// (ARCHITECTURE §11). عناوين عامة فقط، لا أسرار.
class AppConfig {
  const AppConfig({required this.libraryBaseUrl, this.askApiBaseUrl = ''});

  factory AppConfig.fromEnvironment() => const AppConfig(
    libraryBaseUrl: String.fromEnvironment('LIBRARY_BASE_URL'),
    askApiBaseUrl: String.fromEnvironment('ASK_API_BASE_URL'),
  );

  /// جذر مجلد `library/` على GitHub raw، ينتهي بـ `/`.
  final String libraryBaseUrl;

  /// جذر الخادم الوسيط (`https://<name>.workers.dev/`)؛ فارغ = غير منشور بعد.
  final String askApiBaseUrl;

  /// يعيد الرابط إن كان https صالحاً، وإلا null (إعداد ناقص أو غير آمن).
  Uri? get libraryBaseUri => _httpsDirectory(libraryBaseUrl);

  /// رابط الخادم إن كان https صالحاً، وإلا null («اسأل الأديب» غير متاح).
  Uri? get askApiBaseUri => _httpsDirectory(askApiBaseUrl);

  static Uri? _httpsDirectory(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }
}
