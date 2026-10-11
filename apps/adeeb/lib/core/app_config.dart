/// إعداد التطبيق من `--dart-define-from-file=config/app_config.json`
/// (ARCHITECTURE §11). عناوين عامة فقط، لا أسرار.
class AppConfig {
  const AppConfig({required this.libraryBaseUrl});

  factory AppConfig.fromEnvironment() => const AppConfig(
        libraryBaseUrl: String.fromEnvironment('LIBRARY_BASE_URL'),
      );

  /// جذر مجلد `library/` على GitHub raw، ينتهي بـ `/`.
  final String libraryBaseUrl;

  /// يعيد الرابط إن كان https صالحاً، وإلا null (إعداد ناقص أو غير آمن).
  Uri? get libraryBaseUri {
    final uri = Uri.tryParse(libraryBaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }
}
