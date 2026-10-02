/// حفظ الحزمة المقبولة وحالة التحقق على الجهاز (ARCHITECTURE §16.4).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// البيان والحزمة المحفوظان (يُتحقق منهما من جديد عند كل تحميل).
typedef StoredBundle = ({Uint8List manifest, Uint8List bundle});

/// الحزمة المنزّلة في `<مجلد دعم التطبيق>/tables/` (خاص بالتطبيق، بلا إذن
/// تخزين). حزمة واحدة فقط؛ الرجوع دائماً إلى المضمّن.
///
/// التثبيت ذرّي: الملفان في مجلد `s<seq>/`، ثم يُكتب المؤشر `current` في ملف
/// مؤقت ويُعاد تسميته (لحظة الالتزام)، ثم تُحذف المجلدات القديمة. انقطاع في
/// أي لحظة يترك إما الحزمة السابقة كاملة أو الجديدة كاملة.
class UpdateStore {
  UpdateStore(this._baseDir);

  /// مجلد دعم التطبيق (`getApplicationSupportDirectory` في التطبيق، ومجلد
  /// مؤقت في الاختبارات).
  final Future<Directory> Function() _baseDir;

  static const folder = 'tables';
  static const pointerFile = 'current';
  static const manifestFile = 'manifest.json';
  static const bundleFile = 'bundle.json';

  Future<Directory> _root() async =>
      Directory('${(await _baseDir()).path}/$folder');

  /// الحزمة المثبّتة، أو null إن لم توجد.
  Future<StoredBundle?> read() async {
    final root = await _root();
    final pointer = File('${root.path}/$pointerFile');
    if (!await pointer.exists()) return null;
    final seq = int.tryParse((await pointer.readAsString()).trim());
    if (seq == null) throw const FormatException('مؤشر الحزمة تالف.');
    final dir = '${root.path}/s$seq';
    return (
      manifest: await File('$dir/$manifestFile').readAsBytes(),
      bundle: await File('$dir/$bundleFile').readAsBytes(),
    );
  }

  /// يثبّت حزمة مقبولة (بعد التحقق الكامل) بدل أي حزمة سابقة.
  Future<void> install(int seq, List<int> manifest, List<int> bundle) async {
    final root = await _root();
    final dir = Directory('${root.path}/s$seq');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    await File('${dir.path}/$bundleFile').writeAsBytes(bundle, flush: true);
    await File('${dir.path}/$manifestFile').writeAsBytes(manifest, flush: true);
    final tmp = File('${root.path}/$pointerFile.tmp');
    await tmp.writeAsString('$seq', flush: true);
    await tmp.rename('${root.path}/$pointerFile');
    await for (final entry in root.list()) {
      if (entry is Directory && !entry.path.endsWith('/s$seq')) {
        await entry.delete(recursive: true);
      }
    }
  }

  /// يحذف أي حزمة منزّلة (فيعود التطبيق إلى المضمّن).
  Future<void> clear() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

/// حالة التحقق في shared_preferences (§16.4). لا شيء عن المستخدم.
class UpdateState {
  const UpdateState(this._prefs);

  /// أعلى رقم حزمة قُبل على هذا الجهاز (يمنع إعادة حزمة أقدم صحيحة التوقيع).
  static const highestSeqKey = 'data.highestSeq';

  /// وقت آخر تحقق ناجح (ميلي ثانية منذ 1970).
  static const lastCheckOkKey = 'data.lastCheckOk';

  /// وقت آخر محاولة (ناجحة أو فاشلة).
  static const lastAttemptKey = 'data.lastAttempt';

  final SharedPreferences _prefs;

  int get highestSeq => _prefs.getInt(highestSeqKey) ?? 0;
  DateTime? get lastCheckOk => _time(lastCheckOkKey);
  DateTime? get lastAttempt => _time(lastAttemptKey);

  DateTime? _time(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// تُسجَّل قبل الطلب، فانقطاع التطبيق أثناءه يُحسب فشلاً (لا تكرار فوري).
  Future<void> recordAttempt(DateTime now) =>
      _prefs.setInt(lastAttemptKey, now.millisecondsSinceEpoch);

  /// [now] هو وقت المحاولة نفسها، فيتساوى الوقتان عند النجاح.
  Future<void> recordSuccess(DateTime now) =>
      _prefs.setInt(lastCheckOkKey, now.millisecondsSinceEpoch);

  /// يُسجَّل **قبل** التثبيت (`DataUpdater.check`): توقف التطبيق بين
  /// التثبيت والتسجيل لا يترك حداً أدنى أقدم من الحزمة المثبّتة.
  Future<void> recordAccepted(int seq) async {
    if (seq > highestSeq) {
      final ok = await _prefs.setInt(highestSeqKey, seq);
      if (!ok) throw StateError('تعذّر حفظ $highestSeqKey.');
    }
  }

  /// ساعة الجهاز رجعت للخلف: أي وقت مسجّل بعد [now] يُكتب [now]، فتبدأ مهلة
  /// التحقق من الآن (لا تحقق في كل عودة، ولا توقف حتى تلحق الساعة).
  Future<void> clampFuture(DateTime now) async {
    for (final key in [lastAttemptKey, lastCheckOkKey]) {
      final t = _time(key);
      if (t != null && t.isAfter(now)) {
        await _prefs.setInt(key, now.millisecondsSinceEpoch);
      }
    }
  }
}
