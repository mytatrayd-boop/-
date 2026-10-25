import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/analysis_result.dart';
import '../../domain/models/coffee_type.dart';
import '../../domain/models/usage.dart';
import '../../domain/repositories/analysis_repository.dart';

/// تاريخ اليوم بتوقيت الرياض (UTC+3 بلا توقيت صيفي) بصيغة yyyy-MM-dd،
/// بغض النظر عن منطقة الجهاز (SPEC §4 معيار 1).
String riyadhDay(DateTime now) {
  final r = now.toUtc().add(const Duration(hours: 3));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${r.year}-${two(r.month)}-${two(r.day)}';
}

/// محاكاة محلية للعدّاد في وضع العرض فقط (الحد الحقيقي على الخادم).
class DemoAnalysisRepository implements AnalysisRepository {
  DemoAnalysisRepository(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const freeDailyLimit = 2;
  static const dayKey = 'demo_usage_day';
  static const countKey = 'demo_usage_count';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  int _usedToday() {
    if (_prefs.getString(dayKey) != riyadhDay(_clock())) return 0;
    return _prefs.getInt(countKey) ?? 0;
  }

  @override
  Future<Usage> usage() async {
    final remaining = freeDailyLimit - _usedToday();
    return Usage(
      remaining: remaining < 0 ? 0 : remaining,
      limit: freeDailyLimit,
    );
  }

  @override
  Future<AnalysisResult> analyze(
    Uint8List imageBytes, {
    required CoffeeType type,
    required String languageCode,
  }) {
    // تُنفَّذ المحاكاة الكاملة في الدفعة ب (ARCHITECTURE §13).
    throw UnimplementedError('analyze: الدفعة ب');
  }
}
