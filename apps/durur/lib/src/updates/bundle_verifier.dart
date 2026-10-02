/// قبول حزمة بيانات موقّعة أو رفضها (ARCHITECTURE §16.3، §16.6، §16.7، D21).
/// Dart صافٍ. أي فشل ← [UpdateRejected]، والمستدعي يبقى على البيانات الحالية.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../domain/tables.dart';
import '../engine/table_validator.dart';
import '../hijri/hijri_table_validator.dart';
import 'data_bundle.dart';
import 'signed_manifest.dart';

/// سبب رفض حزمة (للاختبارات والتشخيص؛ لا يُعرض للمستخدم).
enum RejectReason {
  /// غلاف البيان أو محتواه تالف أو ناقص.
  badManifest,

  /// `keyId` ليس من المفاتيح الموثوقة المضمّنة.
  unknownKey,

  /// التوقيع لا يطابق المحتوى بالمفتاح العام.
  badSignature,

  /// البيان لتطبيق آخر.
  wrongApp,

  /// رقم مخطط لا يفهمه هذا الإصدار.
  unsupportedSchema,

  /// الحزمة تحتاج إصداراً أحدث من التطبيق.
  appTooOld,

  /// `dataSeq` ليس أكبر من المضمّن ومن آخر حزمة مقبولة.
  notNewer,

  /// حجم الحزمة يخالف البيان.
  sizeMismatch,

  /// بصمة SHA-256 تخالف البيان.
  hashMismatch,

  /// الحزمة لا تُحلَّل (JSON تالف، ملف ناقص، خطأ تحليل).
  badBundle,

  /// meta.json في الحزمة يخالف البيان (الرقم أو النسخة أو المخطط).
  metaMismatch,

  /// الجداول لا تجتاز `TableValidator` بوضع الإطلاق.
  invalidTables,

  /// بداية شهر هجري تختلف عن المضمّن بأكثر من يوم.
  hijriShift,

  /// حُذفت منطقة أو مدينة أو عنصر موجود في المضمّن.
  removedIds,
}

class UpdateRejected implements Exception {
  const UpdateRejected(this.reason, [this.detail = '']);

  final RejectReason reason;
  final String detail;

  @override
  String toString() => 'UpdateRejected(${reason.name}): $detail';
}

/// حزمة اجتازت كل الفحوص.
class VerifiedBundle {
  const VerifiedBundle(this.manifest, this.tables);

  final ManifestPayload manifest;
  final Tables tables;
}

class BundleVerifier {
  /// [trustedKeys]: معرّف المفتاح ← المفتاح العام Ed25519 (base64، 32 بايت).
  const BundleVerifier(this.trustedKeys);

  final Map<String, String> trustedKeys;

  /// الفحوص 1–3 (§16.3): التوقيع، ثم التطبيق والمخطط وأقل بناء، ثم الرقم.
  /// [minSeqExclusive] = max(رقم المضمّن، أعلى رقم قُبل سابقاً).
  Future<ManifestPayload> verifyManifest(
    List<int> manifestBytes, {
    required int appBuild,
    required int minSeqExclusive,
  }) async {
    final SignedManifest envelope;
    try {
      envelope = SignedManifest.parse(manifestBytes);
    } on FormatException catch (e) {
      throw UpdateRejected(RejectReason.badManifest, e.message);
    }

    final publicKey = _publicKey(envelope.keyId);
    if (publicKey == null) {
      throw UpdateRejected(RejectReason.unknownKey, envelope.keyId);
    }
    final bool valid;
    try {
      valid = await DartEd25519().verify(
        envelope.payloadBytes,
        signature: Signature(envelope.signature, publicKey: publicKey),
      );
    } on Object catch (e) {
      throw UpdateRejected(RejectReason.badSignature, '$e');
    }
    if (!valid) throw const UpdateRejected(RejectReason.badSignature);

    final ManifestPayload payload;
    try {
      payload = envelope.decodePayload();
    } on FormatException catch (e) {
      throw UpdateRejected(RejectReason.badManifest, e.message);
    }
    if (payload.app != manifestAppId) {
      throw UpdateRejected(RejectReason.wrongApp, payload.app);
    }
    if (payload.schemaVersion != TablesMeta.supportedSchemaVersion) {
      throw UpdateRejected(
        RejectReason.unsupportedSchema,
        '${payload.schemaVersion}',
      );
    }
    if (payload.minAppBuild > appBuild) {
      throw UpdateRejected(
        RejectReason.appTooOld,
        '${payload.minAppBuild} > $appBuild',
      );
    }
    if (payload.dataSeq <= minSeqExclusive) {
      throw UpdateRejected(
        RejectReason.notNewer,
        '${payload.dataSeq} <= $minSeqExclusive',
      );
    }
    return payload;
  }

  /// الفحوص 4–5 (§16.3) وقواعد التوافق (§16.7) على حزمة منزّلة.
  /// [embedded]: الجداول المضمّنة في التطبيق (مرجع الهجري والمعرّفات).
  Future<VerifiedBundle> verifyBundle(
    ManifestPayload manifest,
    List<int> bundleBytes, {
    required Tables embedded,
  }) async {
    if (bundleBytes.length != manifest.bundle.size) {
      throw UpdateRejected(
        RejectReason.sizeMismatch,
        '${bundleBytes.length} != ${manifest.bundle.size}',
      );
    }
    if (sha256Hex(bundleBytes) != manifest.bundle.sha256) {
      throw const UpdateRejected(RejectReason.hashMismatch);
    }

    final Tables tables;
    try {
      tables = await loadBundleTables(bundleBytes);
    } on FormatException catch (e) {
      throw UpdateRejected(RejectReason.badBundle, e.message);
    } on Object catch (e) {
      throw UpdateRejected(RejectReason.badBundle, '$e');
    }

    final meta = tables.meta;
    if (meta.dataSeq != manifest.dataSeq ||
        meta.dataVersion != manifest.dataVersion ||
        meta.schemaVersion != manifest.schemaVersion) {
      throw UpdateRejected(
        RejectReason.metaMismatch,
        'meta.json: ${meta.dataSeq}/${meta.dataVersion}',
      );
    }

    final report = const TableValidator().validate(tables, release: true);
    if (!report.isValid) {
      throw UpdateRejected(
        RejectReason.invalidTables,
        report.errors.join('\n'),
      );
    }

    final hijri = tables.hijri;
    final embeddedHijri = embedded.hijri;
    if (hijri == null) {
      throw const UpdateRejected(
        RejectReason.badBundle,
        'جدول أم القرى مفقود.',
      );
    }
    if (embeddedHijri != null) {
      final errors = const HijriTableValidator().validate(
        hijri,
        embedded: embeddedHijri,
      );
      if (errors.isNotEmpty) {
        throw UpdateRejected(RejectReason.hijriShift, errors.join('\n'));
      }
    }

    final removed = removedIds(embedded, tables);
    if (removed.isNotEmpty) {
      throw UpdateRejected(RejectReason.removedIds, removed.join('، '));
    }
    return VerifiedBundle(manifest, tables);
  }

  /// كل الفحوص بالترتيب: البيان ثم الحزمة.
  Future<VerifiedBundle> verify(
    List<int> manifestBytes,
    List<int> bundleBytes, {
    required Tables embedded,
    required int appBuild,
    required int minSeqExclusive,
  }) async {
    final manifest = await verifyManifest(
      manifestBytes,
      appBuild: appBuild,
      minSeqExclusive: minSeqExclusive,
    );
    return verifyBundle(manifest, bundleBytes, embedded: embedded);
  }

  SimplePublicKey? _publicKey(String keyId) {
    final encoded = trustedKeys[keyId];
    if (encoded == null) return null;
    final List<int> bytes;
    try {
      bytes = base64.decode(encoded);
    } on FormatException {
      return null;
    }
    if (bytes.length != 32) return null;
    return SimplePublicKey(bytes, type: KeyPairType.ed25519);
  }
}

/// المعرّفات الموجودة في [embedded] والمفقودة في [update] (§16.7): المناطق
/// والمدن (المدينة المحفوظة) والعناصر (حمولات التنبيه `/item/<id>`).
List<String> removedIds(Tables embedded, Tables update) {
  final regions = {for (final r in update.regions) r.id};
  final cities = {for (final c in update.cities) c.id};
  return [
    for (final r in embedded.regions)
      if (!regions.contains(r.id)) 'regions.json:${r.id}',
    for (final c in embedded.cities)
      if (!cities.contains(c.id)) 'cities.json:${c.id}',
    for (final id in embedded.items.keys)
      if (!update.items.containsKey(id)) 'items.json:$id',
  ];
}
