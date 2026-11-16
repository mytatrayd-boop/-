import 'package:flutter/services.dart';

/// منبّه الأذان الكامل بـAlarmKit (آيفون ٢٦ فأحدث، DECISIONS ٣٨): منبّه نظام يرنّ بصوت الأذان كاملاً بلا ضغط
/// ويبقى حتى لو سُحب التطبيق وأُغلق. تحت ٢٦ أو عند رفض الإذن: لا شيء متاح فيُجدول إشعار المقطع القصير.
abstract class AdhanAlarms {
  /// هل AlarmKit متاح على هذا الجهاز (آيفون ٢٦+).
  Future<bool> available();

  /// يطلب الإذن عند أول مرة؛ true إن كان ممنوحاً.
  Future<bool> authorize();

  /// يجدول منبّهاً لكل عنصر؛ يعيد عدد ما جُدول.
  Future<int> schedule(List<({DateTime time, String title})> items);

  /// يلغي كل منبّهات لمحة؛ يعيد عددها.
  Future<int> cancelAll();

  /// عدد منبّهات لمحة المجدولة فعلاً في النظام الآن (للتحقق من عدم تكرارها).
  Future<int> count();
}

/// الأذان الكامل داخل حزمة التطبيق (`Runner/adhan_full.mp3`) كما يسمّيه AlarmKit.
const iosAlarmSound = 'adhan_full.mp3';

/// أقصى عدد منبّهات تُجدول (٦ أيام × ٥ صلوات): تتجدد كلما فُتح التطبيق.
const adhanAlarmLimit = 30;

class ChannelAdhanAlarms implements AdhanAlarms {
  ChannelAdhanAlarms({MethodChannel? channel, this.stopLabel = 'إيقاف'})
      : _channel = channel ?? const MethodChannel('sa.lamha.lamha/adhan_alarm');

  final MethodChannel _channel;
  final String stopLabel;

  @override
  Future<bool> available() async => await _channel.invokeMethod<bool>('available') ?? false;

  @override
  Future<bool> authorize() async => await _channel.invokeMethod<bool>('authorize') ?? false;

  @override
  Future<int> schedule(List<({DateTime time, String title})> items) async {
    final sent = await _channel.invokeMethod<int>('schedule', {
      'items': [
        for (final i in items) {'time': i.time.millisecondsSinceEpoch / 1000, 'title': i.title},
      ],
      'sound': iosAlarmSound,
      'stop': stopLabel,
    });
    return sent ?? 0;
  }

  @override
  Future<int> cancelAll() async => await _channel.invokeMethod<int>('cancelAll') ?? 0;

  @override
  Future<int> count() async => await _channel.invokeMethod<int>('count') ?? 0;
}

/// بلا منبّهات (أندرويد والاختبارات).
class NoopAdhanAlarms implements AdhanAlarms {
  @override
  Future<bool> available() async => false;

  @override
  Future<bool> authorize() async => false;

  @override
  Future<int> schedule(List<({DateTime time, String title})> items) async => 0;

  @override
  Future<int> cancelAll() async => 0;

  @override
  Future<int> count() async => 0;
}
