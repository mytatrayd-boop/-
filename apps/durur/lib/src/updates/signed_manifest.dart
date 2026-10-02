/// البيان الموقّع `manifest.json` (ARCHITECTURE §16.3). Dart صافٍ.
///
/// غلاف يوقَّع فيه نص بايتات خام، فلا مشكلة توحيد JSON:
/// `{"keyId": "k1", "payload": "<base64>", "signature": "<base64 Ed25519>"}`
/// و`payload` بعد فك base64 = [ManifestPayload] بصيغة JSON.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../domain/json_utils.dart';

/// معرّف التطبيق في البيان (يمنع قبول حزمة لتطبيق آخر بالمفتاح نفسه).
const manifestAppId = 'com.durur.durur';

/// اسم ملف الحزمة المتوقع لرقم حزمة (لا مسارات أخرى ولا مجلدات).
String bundleFileName(int dataSeq) => 'bundle-$dataSeq.json';

/// وصف ملف الحزمة داخل البيان.
class BundleRef {
  const BundleRef({
    required this.path,
    required this.sha256,
    required this.size,
  });

  factory BundleRef.fromJson(Object? json) {
    const where = 'manifest.bundle';
    final map = asObject(json, where);
    final sha = readField<String>(map, 'sha256', where);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw const FormatException('$where.sha256: ليس 64 حرفاً ست عشرياً.');
    }
    final size = readField<int>(map, 'size', where);
    if (size <= 0) {
      throw const FormatException('$where.size: يجب أن يكون موجباً.');
    }
    return BundleRef(
      path: readField<String>(map, 'path', where),
      sha256: sha,
      size: size,
    );
  }

  /// اسم الملف بجانب البيان، مثل `bundle-7.json`.
  final String path;

  /// SHA-256 بأحرف ست عشرية صغيرة.
  final String sha256;

  /// الحجم بالبايت.
  final int size;

  Map<String, Object?> toJson() => {
    'path': path,
    'sha256': sha256,
    'size': size,
  };
}

/// محتوى البيان الموقّع.
class ManifestPayload {
  const ManifestPayload({
    this.app = manifestAppId,
    required this.schemaVersion,
    required this.dataSeq,
    required this.dataVersion,
    required this.publishedAt,
    required this.minAppBuild,
    required this.bundle,
  });

  factory ManifestPayload.fromJson(Object? json) {
    const where = 'manifest.payload';
    final map = asObject(json, where);
    final dataSeq = readField<int>(map, 'dataSeq', where);
    final bundle = BundleRef.fromJson(map['bundle']);
    if (bundle.path != bundleFileName(dataSeq)) {
      throw FormatException('$where: مسار الحزمة "${bundle.path}" والمتوقع '
          '"${bundleFileName(dataSeq)}".');
    }
    return ManifestPayload(
      app: readField<String>(map, 'app', where),
      schemaVersion: readField<int>(map, 'schemaVersion', where),
      dataSeq: dataSeq,
      dataVersion: readField<String>(map, 'dataVersion', where),
      publishedAt: readField<String>(map, 'publishedAt', where),
      minAppBuild: readField<int>(map, 'minAppBuild', where),
      bundle: bundle,
    );
  }

  final String app;
  final int schemaVersion;
  final int dataSeq;
  final String dataVersion;

  /// تاريخ النشر `YYYY-MM-DD` (معلومة فقط).
  final String publishedAt;

  /// أقل رقم بناء للتطبيق يفهم هذه الحزمة.
  final int minAppBuild;
  final BundleRef bundle;

  Map<String, Object?> toJson() => {
    'app': app,
    'schemaVersion': schemaVersion,
    'dataSeq': dataSeq,
    'dataVersion': dataVersion,
    'publishedAt': publishedAt,
    'minAppBuild': minAppBuild,
    'bundle': bundle.toJson(),
  };
}

/// الغلاف الموقّع كما هو (قبل التحقق من التوقيع).
class SignedManifest {
  const SignedManifest({
    required this.keyId,
    required this.payloadBytes,
    required this.signature,
  });

  /// يحلل الغلاف فقط؛ يرمي [FormatException] إن كان تالفاً.
  factory SignedManifest.parse(List<int> bytes) {
    const where = 'manifest.json';
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw FormatException('$where: JSON تالف (${e.message}).');
    }
    final map = asObject(json, where);
    // base64 تالف يرمي FormatException أيضاً.
    return SignedManifest(
      keyId: readField<String>(map, 'keyId', where),
      payloadBytes: base64.decode(readField<String>(map, 'payload', where)),
      signature: base64.decode(readField<String>(map, 'signature', where)),
    );
  }

  final String keyId;
  final List<int> payloadBytes;
  final List<int> signature;

  /// يحلل المحتوى (بعد التحقق من التوقيع فقط).
  ManifestPayload decodePayload() {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(payloadBytes));
    } on FormatException catch (e) {
      throw FormatException('manifest.payload: JSON تالف (${e.message}).');
    }
    return ManifestPayload.fromJson(json);
  }

  List<int> encode() => utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      'keyId': keyId,
      'payload': base64.encode(payloadBytes),
      'signature': base64.encode(signature),
    }),
  );
}

/// SHA-256 بأحرف ست عشرية صغيرة.
String sha256Hex(List<int> bytes) {
  final digest = const DartSha256().hashSync(bytes).bytes;
  return [for (final b in digest) b.toRadixString(16).padLeft(2, '0')].join();
}

/// يوقّع محتوى البيان بزوج مفاتيح Ed25519 (للأداة والاختبارات؛ المفتاح
/// الخاص لا يُحفظ في التطبيق ولا المستودع).
Future<SignedManifest> signManifest(
  ManifestPayload payload, {
  required String keyId,
  required KeyPair keyPair,
}) async {
  final bytes = utf8.encode(jsonEncode(payload.toJson()));
  final signature = await DartEd25519().sign(bytes, keyPair: keyPair);
  return SignedManifest(
    keyId: keyId,
    payloadBytes: bytes,
    signature: signature.bytes,
  );
}
