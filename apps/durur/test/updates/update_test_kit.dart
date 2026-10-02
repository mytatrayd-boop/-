import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:durur/src/updates/data_bundle.dart';
import 'package:durur/src/updates/signed_manifest.dart';
import 'package:durur/src/updates/update_fetcher.dart';

/// أدوات اختبار التحديث الموقّع (ARCHITECTURE §16.9). زوج المفاتيح يُولَّد
/// أثناء التشغيل؛ لا مفاتيح اختبار محفوظة في المستودع.

/// ملفات assets/tables الفعلية (JSON محلَّل)، نسخة عميقة قابلة للتعديل.
Future<Map<String, Object?>> assetFiles() async {
  final files = await collectBundleFiles((p) => File(p).readAsString());
  return jsonDecode(jsonEncode(files)) as Map<String, Object?>;
}

/// يجعل كل سجل معتمداً (وضع الإطلاق) ويضبط meta.json لرقم [seq].
Map<String, Object?> approve(Map<String, Object?> files, int seq) {
  Object? walk(Object? node) {
    if (node is Map<String, Object?>) {
      return {
        for (final e in node.entries)
          e.key: e.key == 'approval'
              ? {
                  'status': 'approved',
                  'reviewer': 'مراجع الاختبار',
                  'date': '2026-10-01',
                }
              : walk(e.value),
      };
    }
    if (node is List) return [for (final x in node) walk(x)];
    return node;
  }

  final result = walk(files) as Map<String, Object?>;
  final meta = result['meta.json'] as Map<String, Object?>;
  meta['dataVersion'] = 'test-$seq';
  meta['dataSeq'] = seq;
  return result;
}

/// موقّع اختبار بزوج مفاتيح مؤقت.
class TestSigner {
  TestSigner._(this.keyPair, this.publicKeyBase64);

  static Future<TestSigner> generate() async {
    final keyPair = await DartEd25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return TestSigner._(keyPair, base64.encode(publicKey.bytes));
  }

  static const keyId = 'test';

  final SimpleKeyPair keyPair;
  final String publicKeyBase64;

  Map<String, String> get trustedKeys => {keyId: publicKeyBase64};

  /// بيان موقّع لحزمة [bundle] (الحقول قابلة للتغيير لاختبار الرفض).
  Future<Uint8List> manifest(
    List<int> bundle, {
    required int seq,
    String app = manifestAppId,
    int schemaVersion = 1,
    int minAppBuild = 1,
    String? dataVersion,
    String? path,
    String? sha256,
    int? size,
    String keyId = keyId,
  }) async {
    final payload = ManifestPayload(
      app: app,
      schemaVersion: schemaVersion,
      dataSeq: seq,
      dataVersion: dataVersion ?? 'test-$seq',
      publishedAt: '2026-10-02',
      minAppBuild: minAppBuild,
      bundle: BundleRef(
        path: path ?? bundleFileName(seq),
        sha256: sha256 ?? sha256Hex(bundle),
        size: size ?? bundle.length,
      ),
    );
    final signed = await signManifest(payload, keyId: keyId, keyPair: keyPair);
    return Uint8List.fromList(signed.encode());
  }
}

/// حزمة وبيانها جاهزان.
typedef Release = ({Uint8List manifest, Uint8List bundle});

/// حزمة معتمدة برقم [seq] من الجداول الفعلية، مع تعديل اختياري للملفات.
Future<Release> buildRelease(
  TestSigner signer,
  int seq, {
  void Function(Map<String, Object?> files)? mutate,
  int minAppBuild = 1,
}) async {
  final files = approve(await assetFiles(), seq);
  mutate?.call(files);
  final bundle = Uint8List.fromList(encodeBundle(files));
  return (
    manifest: await signer.manifest(bundle, seq: seq, minAppBuild: minAppBuild),
    bundle: bundle,
  );
}

/// جلب وهمي: مسار ← بايتات أو خطأ، ويسجّل الطلبات.
class FakeFetcher implements UpdateFetcher {
  final Map<String, Uint8List> files = {};
  FetchFailure? failure;
  final List<Uri> requests = [];

  void publish(Release release, int seq) {
    files['manifest.json'] = release.manifest;
    files[bundleFileName(seq)] = release.bundle;
  }

  @override
  Future<Uint8List> get(Uri uri, {required int maxBytes}) async {
    requests.add(uri);
    final f = failure;
    if (f != null) throw FetchException(f);
    final bytes = files[uri.pathSegments.last];
    if (bytes == null) throw const FetchException(FetchFailure.httpStatus);
    if (bytes.length > maxBytes) {
      throw const FetchException(FetchFailure.tooLarge);
    }
    return bytes;
  }
}

/// مجلد مؤقت لمخزن التحديث.
Future<Directory> tempSupportDir() =>
    Directory.systemTemp.createTemp('durur_update_test_');

/// المسار النسبي لجدول منطقة في الحزمة.
String regionFile(String id) =>
    TablesLoader.regionTablePath(id).substring(TablesLoader.root.length + 1);

/// قائمة بدايات الأشهر في ملف الهجري داخل الحزمة.
List<Object?> hijriStarts(Map<String, Object?> files) =>
    (files['hijri_umm_al_qura.json']! as Map)['monthStarts'] as List<Object?>;

String isoPlusDays(String iso, int days) {
  final d = DateTime.parse('${iso}T00:00:00Z').add(Duration(days: days));
  return d.toIso8601String().substring(0, 10);
}
