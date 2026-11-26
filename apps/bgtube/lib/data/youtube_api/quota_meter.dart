import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/youtube_content.dart';
import '../../domain/ports/api_cache_store.dart';
import 'pacific_time.dart';

/// تكلفة الطلبات التقديرية بالوحدات (توثيق الحصة، D29).
abstract final class QuotaCost {
  /// search.list: وحدة واحدة في وعاء «Search Queries».
  static const search = 1;

  /// باقي طرق list: وحدة في الوعاء العام.
  static const read = 1;
}

/// حدّ وعاء واحد: [limit] الحد اليومي، و[stopFraction] نسبة التوقف المحلي.
class BucketLimit {
  const BucketLimit(this.limit, {this.stopFraction = 1.0});
  final int limit;
  final double stopFraction;
  int get stopAt => (limit * stopFraction).floor();
}

/// عدّاد تقديري محلي لوعاءي الحصة (D9/D29). يُصفَّر ضمنياً لأن المفتاح يوم
/// المحيط الهادئ. الحدود قابلة للضبط (الافتراضي من التوثيق: بحث 100 طلب، عام
/// 10,000 وحدة يتوقف عند 95% هامشاً لتقدير التكلفة).
class QuotaMeter {
  QuotaMeter(
    this._store, {
    this.general = const BucketLimit(10000, stopFraction: 0.95),
    this.search = const BucketLimit(100),
    Clock? clock,
  }) : _clock = clock ?? const Clock();

  final QuotaStore _store;
  final Clock _clock;
  final BucketLimit general;
  final BucketLimit search;

  BucketLimit limitOf(QuotaBucket b) => b == QuotaBucket.search ? search : general;

  String get _day => pacificDayKey(_clock.now());

  /// فشل قراءة العدّاد لا يمنع الطلب (الخادم هو الحكم الأخير).
  Future<int> _used(QuotaBucket b) async {
    try {
      return await _store.unitsFor(_day, b.name);
    } catch (e) {
      debugPrint('quota read failed: ${e.runtimeType}');
      return 0;
    }
  }

  /// يُسمح إن بقي `المستعمل + التكلفة` ≤ حد التوقف.
  Future<bool> canSpend(QuotaBucket b, int cost) async => await _used(b) + cost <= limitOf(b).stopAt;

  Future<void> spend(QuotaBucket b, int cost) async {
    try {
      await _store.add(_day, b.name, cost);
    } catch (e) {
      debugPrint('quota write failed: ${e.runtimeType}');
    }
  }

  /// الخادم ردّ quotaExceeded لنقطة نهاية من هذا الوعاء: يتوقف هو وحده حتى منتصف
  /// ليل المحيط الهادئ (نفاد البحث لا يوقف الرئيسية).
  Future<void> markExhausted(QuotaBucket b) async {
    try {
      await _store.raiseTo(_day, b.name, limitOf(b).limit);
    } catch (e) {
      debugPrint('quota write failed: ${e.runtimeType}');
    }
  }

  Future<QuotaUsage> today() async {
    Future<BucketUsage> usage(QuotaBucket b) async {
      final l = limitOf(b);
      return BucketUsage(used: await _used(b), limit: l.limit, stopAt: l.stopAt);
    }

    return QuotaUsage(general: await usage(QuotaBucket.general), search: await usage(QuotaBucket.search));
  }
}
