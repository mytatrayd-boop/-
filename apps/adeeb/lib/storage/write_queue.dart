/// طابور كتابة واحد لكل ملف قاعدة بيانات داخل التطبيق: الاستيراد والحذف
/// (مع VACUUM) وحفظ الموضع والمفضلة لا تتزاحم، فلا تفشل كتابة صغيرة بـ
/// SQLITE_BUSY أثناء معاملة استيراد طويلة. Dart صافٍ.
library;

final _queues = <String, Future<void>>{};

/// ينفّذ [task] بعد انتهاء كل الكتابات السابقة على [dbPath]. فشل مهمة لا
/// يوقف ما بعدها.
Future<T> enqueueWrite<T>(String dbPath, Future<T> Function() task) {
  final previous = _queues[dbPath] ?? Future<void>.value();
  final result = previous.then((_) => task());
  final tail = result.then<void>((_) {}, onError: (Object _) {});
  _queues[dbPath] = tail;
  tail.then((_) {
    if (identical(_queues[dbPath], tail)) _queues.remove(dbPath);
  });
  return result;
}
