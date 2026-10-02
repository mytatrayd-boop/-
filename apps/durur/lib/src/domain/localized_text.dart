import 'json_utils.dart';

/// نص من البيانات بصيغة {"ar": "..."}؛ تُضاف "en" لاحقاً بلا تغيير المخطط.
class LocalizedText {
  const LocalizedText(this.values);

  factory LocalizedText.fromJson(Object? json, String where) {
    final map = asObject(json, where);
    final values = <String, String>{};
    map.forEach((lang, text) {
      if (text is! String) {
        throw FormatException('$where: النص للغة "$lang" ليس نصاً.');
      }
      values[lang] = text;
    });
    if ((values['ar'] ?? '').trim().isEmpty) {
      throw FormatException('$where: النص العربي "ar" مفقود أو فارغ.');
    }
    return LocalizedText(values);
  }

  final Map<String, String> values;

  String get ar => values['ar']!;

  /// النص بلغة معيّنة، وإلا العربية.
  String of(String languageCode) => values[languageCode] ?? ar;

  @override
  String toString() => ar;
}
