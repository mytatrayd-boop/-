import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/demo_controls.dart';
import '../../domain/models/analysis_result.dart';
import '../../domain/models/app_failure.dart';
import '../../domain/models/coffee_type.dart';
import '../../domain/models/usage.dart';
import '../../domain/repositories/analysis_repository.dart';
import 'demo_samples.dart';

/// تاريخ اليوم بتوقيت الرياض (UTC+3 بلا توقيت صيفي) بصيغة yyyy-MM-dd،
/// بغض النظر عن منطقة الجهاز (SPEC §4 معيار 1).
String riyadhDay(DateTime now) {
  final r = now.toUtc().add(const Duration(hours: 3));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${r.year}-${two(r.month)}-${two(r.day)}';
}

/// محاكاة محلية للتحليل والعدّاد في وضع العرض فقط (الحد الحقيقي على الخادم).
/// النتيجة ثابتة ومطابقة لعقد SPEC §3 (تمر عبر AnalysisResult.fromJson).
class DemoAnalysisRepository implements AnalysisRepository, RejectionSimulator {
  DemoAnalysisRepository(
    this._prefs, {
    DateTime Function()? clock,
    this.latency = const Duration(seconds: 2),
  }) : _clock = clock ?? DateTime.now;

  static const freeDailyLimit = 2;
  static const maxImageBytes = 1536 * 1024; // نفس حد الخادم (1.5 م.ب).
  static const dayKey = 'demo_usage_day';
  static const countKey = 'demo_usage_count';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final Duration latency;

  @override
  bool rejectNext = false;

  int _usedToday() {
    if (_prefs.getString(dayKey) != riyadhDay(_clock())) return 0;
    return _prefs.getInt(countKey) ?? 0;
  }

  Usage _usage() {
    final remaining = freeDailyLimit - _usedToday();
    return Usage(remaining: remaining < 0 ? 0 : remaining, limit: freeDailyLimit);
  }

  @override
  Future<Usage> usage() async => _usage();

  @override
  Future<AnalysisResult> analyze(
    Uint8List imageBytes, {
    required CoffeeType type,
    required String languageCode,
  }) async {
    if (imageBytes.length > maxImageBytes) {
      throw const AppFailure(FailureCode.imageTooLarge);
    }
    if (_usedToday() >= freeDailyLimit) {
      throw const AppFailure(FailureCode.limitReached);
    }
    await Future<void>.delayed(latency);
    if (rejectNext) {
      rejectNext = false;
      // المرفوض لا يُحتسب (SPEC §4 معيار 3).
      return AnalysisResult.fromJson({
        ...demoRejectedJson,
        'usage': _usage().toJson(),
      });
    }
    // «حجز» المحاولة بعد التأخير كما يفعل الخادم.
    final used = _usedToday();
    if (used >= freeDailyLimit) throw const AppFailure(FailureCode.limitReached);
    await _prefs.setString(dayKey, riyadhDay(_clock()));
    await _prefs.setInt(countKey, used + 1);
    return AnalysisResult.fromJson({
      ...demoResultJson(type, languageCode),
      'usage': _usage().toJson(),
    });
  }
}
