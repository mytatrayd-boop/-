/// معرّف الجهاز العشوائي (ARCHITECTURE §8.2، D11): UUID v4 من
/// `Random.secure()`، لا يرتبط بالجهاز ولا بالحساب ولا بالمعلن. Dart صافٍ.
library;

import 'dart:math';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// هل [value] UUID v4 بالصيغة التي يقبلها الخادم (حروف صغيرة)؟
bool isUuidV4(String value) => _uuidV4.hasMatch(value);

/// UUID v4 جديد (RFC 9562): 122 بتاً عشوائياً، والإصدار 4، والمتغير 10xx.
String generateUuidV4([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10).join()}';
}

/// يقرأ المعرّف المحفوظ أو يولّد واحداً ويحفظه. [read] و[write] تخزين محلي
/// (shared_preferences في التطبيق).
Future<String> loadOrCreateDeviceId({
  required String? Function() read,
  required Future<void> Function(String id) write,
  Random? random,
}) async {
  final saved = read();
  if (saved != null && isUuidV4(saved)) return saved;
  final id = generateUuidV4(random);
  await write(id);
  return id;
}
