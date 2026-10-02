/// إعدادات تحديث البيانات الموقّع (ARCHITECTURE §16.1، D21). Dart صافٍ.
library;

import '../domain/tables.dart';

/// رابط مصدر التحديث من `--dart-define-from-file=config/app_config.json`
/// (`UPDATE_BASE_URL`). ليس سراً لكنه لا يُكتب في الكود. فارغ أو غير صالح
/// (ليس https بنطاق، أو فيه معاملات/جزء/بيانات دخول) ← الميزة معطّلة كلياً
/// ولا يُرسل أي طلب.
class UpdateConfig {
  const UpdateConfig({this.baseUrl = ''}) : _root = null;

  /// للاختبارات فقط: جذر مجلد المخطط كما هو بلا فحص https (خادم محلي http).
  const UpdateConfig.unchecked(Uri root) : baseUrl = '', _root = root;

  factory UpdateConfig.fromEnvironment() =>
      const UpdateConfig(baseUrl: String.fromEnvironment('UPDATE_BASE_URL'));

  /// مثل `https://<الحساب>.github.io/durur-data`.
  final String baseUrl;

  final Uri? _root;

  /// مجلد المخطط الذي يفهمه هذا الإصدار: `<base>/v1/`، أو null = معطّل.
  Uri? get versionRoot {
    if (_root != null) return _root;
    final raw = baseUrl.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(
      path: '${path}v${TablesMeta.supportedSchemaVersion}/',
    );
  }

  bool get isEnabled => versionRoot != null;

  /// `<base>/v1/manifest.json`.
  Uri get manifestUri => versionRoot!.resolve(manifestFile);

  /// ملف الحزمة بجانب البيان (الاسم مفحوص مسبقاً: `bundle-<seq>.json`).
  Uri bundleUri(String fileName) => versionRoot!.resolve(fileName);

  static const manifestFile = 'manifest.json';
}
