/// تحديث البيانات الموقّع: التحقق والتنزيل والتثبيت، وتحميل المثبّت عند الفتح
/// (ARCHITECTURE §16، D21).
library;

import 'dart:math' as math;

import '../domain/tables.dart';
import 'bundle_verifier.dart';
import 'signed_manifest.dart';
import 'update_config.dart';
import 'update_fetcher.dart';
import 'update_store.dart';

/// نتيجة محاولة تحقق.
enum UpdateOutcome {
  /// الميزة معطّلة (لا رابط أو لا مفتاح موثوق): لا طلب.
  disabled,

  /// لم يحن الموعد أو أثناء الإعداد الأولي: لا طلب.
  notDue,

  /// البيان صحيح ولا حزمة أحدث (نجاح).
  upToDate,

  /// قُبلت حزمة جديدة وثُبّتت (نجاح).
  updated,

  /// فشل الطلب أو رُفضت الحزمة؛ البيانات الحالية باقية.
  failed,
}

/// نوع الفشل لسطر النتيجة في الإعدادات (DESIGN 8.7)؛ لا يُعرض السبب التقني.
enum UpdateFailure {
  /// لا إنترنت، مهلة، رد غير 200 (ومنه 304)، حجم زائد، تحويل مرفوض.
  network,

  /// بيان أو حزمة مرفوضة (توقيع، رقم، بصمة، مدقق، توافق) أو تعذّر التثبيت.
  verify,
}

/// حدّا الحجم (§16.2).
const maxManifestBytes = 4 * 1024;
const maxBundleBytes = 2 * 1024 * 1024;

class DataUpdater {
  DataUpdater({
    required this.config,
    required this.verifier,
    required this.fetcher,
    required this.store,
    required this.state,
  });

  final UpdateConfig config;
  final BundleVerifier verifier;
  final UpdateFetcher fetcher;
  final UpdateStore store;
  final UpdateState state;

  /// آخر سبب فشل (للاختبارات والتشخيص فقط).
  Object? lastError;

  /// نوع آخر فشل، أو null إن لم تفشل آخر محاولة.
  UpdateFailure? get lastFailure => switch (lastError) {
    null => null,
    FetchException() => UpdateFailure.network,
    _ => UpdateFailure.verify,
  };

  bool get isEnabled => config.isEnabled && verifier.trustedKeys.isNotEmpty;

  /// محاولة واحدة الآن (المستدعي قرر أن الموعد حان). لا ترمي.
  Future<UpdateOutcome> check({
    required Tables embedded,
    required int appBuild,
    required DateTime now,
  }) async {
    lastError = null;
    if (!isEnabled) return UpdateOutcome.disabled;
    await state.recordAttempt(now);
    try {
      final floor = math.max(embedded.meta.dataSeq, state.highestSeq);
      final manifestBytes = await fetcher.get(
        config.manifestUri,
        maxBytes: maxManifestBytes,
      );
      final ManifestPayload manifest;
      try {
        manifest = await verifier.verifyManifest(
          manifestBytes,
          appBuild: appBuild,
          minSeqExclusive: floor,
        );
      } on UpdateRejected catch (e) {
        if (e.reason != RejectReason.notNewer) rethrow;
        // بيان صحيح التوقيع بلا جديد: الحالة المعتادة أسبوعياً.
        await state.recordSuccess(now);
        return UpdateOutcome.upToDate;
      }
      if (manifest.bundle.size > maxBundleBytes) {
        throw UpdateRejected(
          RejectReason.sizeMismatch,
          '${manifest.bundle.size} > $maxBundleBytes',
        );
      }
      final bundleBytes = await fetcher.get(
        config.bundleUri(manifest.bundle.path),
        maxBytes: manifest.bundle.size,
      );
      final verified = await verifier.verifyBundle(
        manifest,
        bundleBytes,
        embedded: embedded,
      );
      // الحد الأدنى يُرفع **قبل** التثبيت: إن توقف التطبيق بين الخطوتين لا
      // تُقبل لاحقاً حزمة أقدم من المثبّتة (رقمها بين القديم والجديد). وإن
      // فشل التثبيت نفسه تبقى البيانات الحالية، والحزمة نفسها لا تُعاد حتى
      // رقم أحدث (اتجاه الأمان).
      await state.recordAccepted(verified.manifest.dataSeq);
      await store.install(verified.manifest.dataSeq, manifestBytes, bundleBytes);
      await state.recordSuccess(now);
      return UpdateOutcome.updated;
    } on Object catch (e) {
      lastError = e;
      return UpdateOutcome.failed;
    }
  }
}

/// يحمّل الحزمة المثبّتة فوق [embedded] عند كل فتح (§16.4): تحقق التوقيع
/// والبصمة والمدقق من جديد، ورقمها أكبر من المضمّن. أي رفض ← null وحذفها
/// (فيعود التطبيق إلى المضمّن، ومنه بعد تحديث متجر يضمّن رقماً مساوياً أو
/// أحدث). تعذّر الوصول للمجلد أو رقم البناء ← null بلا حذف.
Future<Tables?> loadInstalledTables({
  required Tables embedded,
  required UpdateStore store,
  required BundleVerifier verifier,
  required Future<int> Function() appBuild,
}) async {
  final StoredBundle? stored;
  try {
    stored = await store.read();
  } on Object {
    // مؤشر أو ملف تالف/مفقود ← حذف؛ وإن كان المجلد نفسه غير متاح (البلجن
    // في الاختبارات) فالحذف يفشل بصمت.
    await _clearQuietly(store);
    return null;
  }
  if (stored == null) return null;
  final int build;
  try {
    build = await appBuild();
  } on Object {
    return null; // لا نحذف حزمة سليمة لخطأ عابر في قراءة رقم البناء.
  }
  try {
    final verified = await verifier.verify(
      stored.manifest,
      stored.bundle,
      embedded: embedded,
      appBuild: build,
      minSeqExclusive: embedded.meta.dataSeq,
    );
    return verified.tables;
  } on Object {
    await _clearQuietly(store);
    return null;
  }
}

Future<void> _clearQuietly(UpdateStore store) async {
  try {
    await store.clear();
  } on Object {
    // يُعاد في الفتح التالي.
  }
}
