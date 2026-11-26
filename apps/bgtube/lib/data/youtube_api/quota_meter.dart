import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/youtube_content.dart';
import '../../domain/ports/api_cache_store.dart';
import 'pacific_time.dart';

/// تكلفة الطلبات التقديرية بالوحدات (ARCHITECTURE: الحصة).
abstract final class QuotaCost {
  static const search = 100;
  static const read = 1;
}

/// عدّاد تقديري محلي للحصة اليومية (D9/D29). يُصفَّر ضمنياً لأن المفتاح يوم
/// المحيط الهادئ. يتوقف عند 95% من الحد حتى لا نصل إلى رفض الخادم.
class QuotaMeter {
  QuotaMeter(this._store, {this.dailyLimit = 10000, this.stopFraction = 0.95, Clock? clock})
      : _clock = clock ?? const Clock();

  final QuotaStore _store;
  final Clock _clock;
  final int dailyLimit;
  final double stopFraction;

  int get stopAt => (dailyLimit * stopFraction).floor();

  String get _day => pacificDayKey(_clock.now());

  /// فشل قراءة العدّاد لا يمنع الطلب (الخادم هو الحكم الأخير).
  Future<int> _used() async {
    try {
      return await _store.unitsFor(_day);
    } catch (e) {
      debugPrint('quota read failed: ${e.runtimeType}');
      return 0;
    }
  }

  Future<bool> canSpend(int cost) async => await _used() + cost <= stopAt;

  Future<void> spend(int cost) async {
    try {
      await _store.add(_day, cost);
    } catch (e) {
      debugPrint('quota write failed: ${e.runtimeType}');
    }
  }

  /// الخادم ردّ quotaExceeded: لا طلبات حتى منتصف ليل المحيط الهادئ.
  Future<void> markExhausted() async {
    try {
      await _store.raiseTo(_day, dailyLimit);
    } catch (e) {
      debugPrint('quota write failed: ${e.runtimeType}');
    }
  }

  Future<QuotaUsage> today() async {
    final used = await _used();
    final left = stopAt - used;
    return QuotaUsage(
      used: used,
      limit: dailyLimit,
      exhausted: left <= 0,
      searchesLeft: left <= 0 ? 0 : left ~/ QuotaCost.search,
    );
  }
}
