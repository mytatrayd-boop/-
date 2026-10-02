// توليد مفتاح توقيع حزم البيانات، وبناء حزمة موقّعة (ARCHITECTURE §16.3، §16.8، D21).
// للمالك فقط، على جهازه. المفتاح الخاص لا يُطبع ولا يُكتب داخل المستودع أبداً.
//
// 1) توليد زوج المفاتيح (مرة واحدة):
//    dart run tool/sign_bundle.dart keygen --out ~/durur-keys/durur-data.ed25519
//    ← يكتب المفتاح الخاص في الملف (صلاحية 600) ويطبع المفتاح العام فقط
//      لِلَصقه في lib/src/updates/trusted_keys.dart.
//    يرفض الكتابة داخل مجلد المشروع أو فوق ملف موجود.
//
// 2) بناء الحزمة وتوقيعها (لكل نشر، بعد اعتماد البيانات):
//    DURUR_SIGNING_KEY_FILE=~/durur-keys/durur-data.ed25519 \
//      dart run tool/sign_bundle.dart sign --key-id k1 --out <مجلد v1 في مستودع البيانات>
//    أو المفتاح نفسه (base64) في متغير البيئة DURUR_SIGNING_KEY بدل الملف
//    (مثل سر GitHub Actions).
//    خيارات: --tables <مجلد الجداول> (الافتراضي assets/tables)،
//            --min-app-build <رقم> (الافتراضي 1)، --published-at YYYY-MM-DD.
//    رقم الحزمة ونسختها من meta.json (dataSeq ≥ 1 يزيد مع كل نشر، وdataVersion).
//    يرفض التوقيع إن لم تجتز الجداول validate_tables --release.
//    الناتج: bundle-<seq>.json و manifest.json. النشر للمستخدمين = رفعهما،
//    وهو إجراء نهائي يحتاج موافقة المالك الصريحة لكل حزمة.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/table_validator.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:durur/src/updates/bundle_verifier.dart';
import 'package:durur/src/updates/data_bundle.dart';
import 'package:durur/src/updates/signed_manifest.dart';

const keyFileEnv = 'DURUR_SIGNING_KEY_FILE';
const keyEnv = 'DURUR_SIGNING_KEY';

Future<void> main(List<String> args) async {
  if (args.isEmpty) _usage();
  final options = _parseOptions(args.skip(1).toList());
  try {
    switch (args.first) {
      case 'keygen':
        await _keygen(options);
      case 'sign':
        await _sign(options);
      default:
        _usage();
    }
  } on _ToolError catch (e) {
    stderr.writeln('خطأ: ${e.message}');
    exit(1);
  }
}

Never _usage() {
  stderr.writeln(
    'الاستخدام:\n'
    '  dart run tool/sign_bundle.dart keygen --out <ملف خارج المستودع>\n'
    '  $keyFileEnv=<الملف> dart run tool/sign_bundle.dart sign '
    '--key-id k1 --out <مجلد>',
  );
  exit(64);
}

class _ToolError implements Exception {
  const _ToolError(this.message);
  final String message;
}

Map<String, String> _parseOptions(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--') || i + 1 >= args.length) {
      throw _ToolError('خيار غير صالح: $a');
    }
    options[a.substring(2)] = args[++i];
  }
  return options;
}

String _expandHome(String path) {
  final home = Platform.environment['HOME'];
  if (home != null && (path == '~' || path.startsWith('~/'))) {
    return '$home${path.substring(1)}';
  }
  return path;
}

/// المسار الحقيقي بعد تتبّع الروابط الرمزية، ولو لم يوجد الملف بعد: أقرب
/// أصل موجود يُحلّ بـ `resolveSymbolicLinksSync` ثم يُلحق به الباقي.
String _realPath(String path) {
  final sep = Platform.pathSeparator;
  var current = File(path).absolute.path;
  final rest = <String>[];
  while (FileSystemEntity.typeSync(current, followLinks: false) ==
      FileSystemEntityType.notFound) {
    final parent = File(current).parent.path;
    if (parent == current) break;
    rest.insert(0, current.substring(current.lastIndexOf(sep) + 1));
    current = parent;
  }
  final parts = File(current)
      .resolveSymbolicLinksSync()
      .split(sep)
      .where((p) => p.isNotEmpty)
      .toList();
  for (final segment in rest) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(segment);
    }
  }
  return '$sep${parts.join(sep)}';
}

/// هل [path] داخل مجلد المشروع أو مستودع git الذي يحتويه؟ المساران يُقارنان
/// بعد تتبّع الروابط الرمزية (رابط خارج المستودع يشير إلى داخله ← داخل).
bool _insideRepository(String path) {
  final target = _realPath(path);
  final cwd = _realPath(Directory.current.path);
  bool under(String dir) =>
      target == dir || target.startsWith('$dir${Platform.pathSeparator}');
  var dir = Directory(cwd);
  while (true) {
    if (Directory('${dir.path}/.git').existsSync() ||
        File('${dir.path}/.git').existsSync()) {
      return under(dir.path);
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return under(cwd);
}

Future<void> _keygen(Map<String, String> options) async {
  final out = options['out'];
  if (out == null) throw const _ToolError('حدد --out <ملف خارج المستودع>.');
  final path = File(_expandHome(out)).absolute.path;
  if (_insideRepository(path)) {
    throw const _ToolError(
      'المفتاح الخاص لا يُكتب داخل المستودع. اختر مجلداً خارجه.',
    );
  }
  final file = File(path);
  if (file.existsSync()) {
    throw _ToolError('الملف موجود ولن يُكتب فوقه: $path');
  }
  final algorithm = DartEd25519();
  final keyPair = await algorithm.newKeyPair();
  final seed = await keyPair.extractPrivateKeyBytes();
  final publicKey = await keyPair.extractPublicKey();

  file.parent.createSync(recursive: true);
  // يُنشأ فارغاً بصلاحية 600 قبل كتابة المفتاح.
  file.createSync();
  if (!Platform.isWindows) {
    final chmod = Process.runSync('chmod', ['600', path]);
    if (chmod.exitCode != 0) {
      file.deleteSync();
      throw const _ToolError('تعذّر ضبط صلاحية الملف (chmod 600).');
    }
  }
  file.writeAsStringSync('${base64.encode(seed)}\n', flush: true);

  final keyId = options['key-id'] ?? 'k1';
  print('كُتب المفتاح الخاص في: $path (لا تشاركه ولا ترفعه، واحفظ نسخة '
      'احتياطية غير متصلة).');
  print('المفتاح العام (ليس سراً) — ألصقه في '
      'lib/src/updates/trusted_keys.dart:');
  print("  '$keyId': '${base64.encode(publicKey.bytes)}',");
}

Future<KeyPair> _loadPrivateKey() async {
  final fromFile = Platform.environment[keyFileEnv];
  final fromEnv = Platform.environment[keyEnv];
  final String encoded;
  if (fromFile != null && fromFile.isNotEmpty) {
    final file = File(_expandHome(fromFile));
    if (!file.existsSync()) {
      throw const _ToolError('ملف المفتاح في $keyFileEnv غير موجود.');
    }
    encoded = file.readAsStringSync().trim();
  } else if (fromEnv != null && fromEnv.isNotEmpty) {
    encoded = fromEnv.trim();
  } else {
    throw const _ToolError('حدد المفتاح الخاص في $keyFileEnv (مسار ملف) '
        'أو $keyEnv (base64).');
  }
  final List<int> seed;
  try {
    seed = base64.decode(encoded);
  } on FormatException {
    // لا نطبع المحتوى أبداً.
    throw const _ToolError('المفتاح الخاص ليس base64 صالحاً.');
  }
  if (seed.length != 32) {
    throw const _ToolError('المفتاح الخاص يجب أن يكون 32 بايتاً (Ed25519).');
  }
  return DartEd25519().newKeyPairFromSeed(seed);
}

Future<void> _sign(Map<String, String> options) async {
  final keyId = options['key-id'];
  final out = options['out'];
  if (keyId == null || out == null) {
    throw const _ToolError('حدد --key-id و--out.');
  }
  final tablesDir = options['tables'] ?? TablesLoader.root;
  final minAppBuild = int.tryParse(options['min-app-build'] ?? '1');
  if (minAppBuild == null || minAppBuild < 0) {
    throw const _ToolError('--min-app-build رقم غير صالح.');
  }
  final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final publishedAt = options['published-at'] ?? today;

  // 1. الجداول من القرص (المسارات assets/tables/... ← المجلد المحدد).
  final files = await collectBundleFiles((path) {
    final rel = path.substring(TablesLoader.root.length + 1);
    return File('$tablesDir/$rel').readAsString();
  });
  final bundleBytes = encodeBundle(files);

  // 2. التحليل والمدقق بوضع الإطلاق على الحزمة نفسها (كما سيفعل التطبيق).
  final Tables tables;
  try {
    tables = await loadBundleTables(bundleBytes);
  } on FormatException catch (e) {
    throw _ToolError('الجداول لا تُحلَّل: ${e.message}');
  }
  final report = const TableValidator().validate(tables, release: true);
  if (!report.isValid) {
    for (final e in report.errors) {
      stderr.writeln('خطأ: $e');
    }
    throw const _ToolError(
      'الجداول لا تجتاز validate_tables --release؛ لا توقيع.',
    );
  }
  final seq = tables.meta.dataSeq;
  if (seq < 1) {
    throw const _ToolError('meta.json: dataSeq يجب أن يكون ≥ 1 ويزيد مع كل '
        'نشر.');
  }

  // 3. البيان والتوقيع.
  final keyPair = await _loadPrivateKey();
  final payload = ManifestPayload(
    schemaVersion: tables.meta.schemaVersion,
    dataSeq: seq,
    dataVersion: tables.meta.dataVersion,
    publishedAt: publishedAt,
    minAppBuild: minAppBuild,
    bundle: BundleRef(
      path: bundleFileName(seq),
      sha256: sha256Hex(bundleBytes),
      size: bundleBytes.length,
    ),
  );
  final manifest = await signManifest(
    payload,
    keyId: keyId,
    keyPair: keyPair,
  );
  final manifestBytes = manifest.encode();
  if (manifestBytes.length > 4 * 1024) {
    throw const _ToolError('البيان أكبر من 4 كيلوبايت.');
  }

  // 4. تحقق ذاتي بالمفتاح العام المقابل (كما سيتحقق التطبيق)، والهجري وعدم
  // الحذف مقابل assets/tables الحقيقية في المشروع (المضمّنة في التطبيق) لا
  // مقابل الجداول المُوقَّعة نفسها.
  final Tables embedded;
  try {
    embedded = await TablesLoader((path) => File(path).readAsString()).load();
  } on Object catch (e) {
    throw _ToolError('تعذّر قراءة ${TablesLoader.root} الحقيقية للمقارنة '
        '(شغّل الأداة من مجلد المشروع): $e');
  }
  if (seq <= embedded.meta.dataSeq) {
    stderr.writeln('تنبيه: dataSeq ($seq) ليس أكبر من المضمّن في التطبيق '
        '(${embedded.meta.dataSeq})؛ لن تصل الحزمة إلا لنسخ أقدم.');
  }
  final publicKey = base64.encode(
    (await keyPair.extractPublicKey() as SimplePublicKey).bytes,
  );
  try {
    await BundleVerifier({keyId: publicKey}).verify(
      manifestBytes,
      bundleBytes,
      embedded: embedded,
      appBuild: minAppBuild,
      minSeqExclusive: seq - 1,
    );
  } on UpdateRejected catch (e) {
    throw _ToolError('فشل التحقق الذاتي: $e');
  }

  // 5. الكتابة.
  final dir = Directory(_expandHome(out))..createSync(recursive: true);
  final bundleFile = File('${dir.path}/${bundleFileName(seq)}');
  if (bundleFile.existsSync()) {
    throw _ToolError('${bundleFile.path} موجود: كل نشر برقم جديد.');
  }
  bundleFile.writeAsBytesSync(bundleBytes, flush: true);
  File('${dir.path}/manifest.json').writeAsBytesSync(manifestBytes, flush: true);

  print('وُقّعت الحزمة $seq (${tables.meta.dataVersion})، '
      '${bundleBytes.length} بايت، sha256 ${payload.bundle.sha256}.');
  print('المفتاح العام المستخدم ($keyId): $publicKey');
  print('تأكد أنه في lib/src/updates/trusted_keys.dart قبل النشر.');
  print('الناتج في ${dir.path}: ${bundleFileName(seq)} و manifest.json.');
}
