/// أدوات قراءة JSON برسائل خطأ واضحة تذكر مكان الخطأ.
library;

T readField<T>(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException('$where: الحقل "$key" مفقود أو نوعه غير صحيح '
      '(المتوقع $T، الموجود ${value.runtimeType}).');
}

T? readOptional<T>(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value == null) return null;
  if (value is T) return value;
  throw FormatException('$where: الحقل "$key" نوعه غير صحيح '
      '(المتوقع $T، الموجود ${value.runtimeType}).');
}

Map<String, dynamic> asObject(Object? value, String where) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$where: المتوقع كائن JSON.');
}

List<Object?> asList(Object? value, String where) {
  if (value is List) return value;
  throw FormatException('$where: المتوقع قائمة JSON.');
}
