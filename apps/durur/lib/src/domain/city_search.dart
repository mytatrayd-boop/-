import 'city.dart';

final _diacritics = RegExp('[ً-ٰٟـ]');
final _spaces = RegExp(r'\s+');

/// تطبيع نص عربي للبحث (ARCHITECTURE §7، DESIGN 8.3): إزالة التشكيل
/// والتطويل، وأ/إ/آ/ٱ ← ا، ؤ ← و، ئ ← ي، ة ← ه، ى ← ي، وتوحيد المسافات.
String normalizeArabic(String input) {
  final text = input.replaceAll(_diacritics, '');
  final out = StringBuffer();
  for (final rune in text.runes) {
    out.write(switch (rune) {
      0x0623 || 0x0625 || 0x0622 || 0x0671 => 'ا',
      0x0624 => 'و',
      0x0626 || 0x0649 => 'ي',
      0x0629 => 'ه',
      _ => String.fromCharCode(rune),
    });
  }
  return out.toString().trim().replaceAll(_spaces, ' ');
}

/// المدن المطابقة لنص البحث (احتواء بعد التطبيع) وللدولة إن حُددت،
/// بترتيبها الأصلي. البحث الفارغ يُرجع كل مدن الدولة.
List<City> searchCities(
  List<City> cities, {
  String query = '',
  Country? country,
}) {
  final q = normalizeArabic(query);
  return [
    for (final city in cities)
      if ((country == null || city.country == country) &&
          (q.isEmpty || normalizeArabic(city.name.ar).contains(q)))
        city,
  ];
}
