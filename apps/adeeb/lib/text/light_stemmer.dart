/// الجذع الخفيف لعمود `stem` في فهرس البحث (ARCHITECTURE §6، D8): حذف سابقة
/// شائعة واحدة ولاحقة شائعة واحدة بشرط بقاء 3 أحرف على الأقل، و4 أحرف للسابقتين
/// المفردتين «و/ف» (حتى لا تصير «فكرة» «كره» ولا «وجود» «جود»). ليس تحليلاً
/// صرفياً. يعمل على كلمة مطبَّعة سلفاً بـ `normalizeArabic`. Dart صافٍ.
library;

/// الأطول أولاً حتى تُفضَّل «وال» على «و».
const _prefixes = ['وال', 'فال', 'بال', 'كال', 'لل', 'ال', 'و', 'ف'];
const _suffixes = ['هما', 'ها', 'هم', 'كم', 'ين', 'ون', 'ات'];

const _minLength = 3;

/// «و» و«ف» وحدهما كثيراً ما تكونان من أصل الكلمة (فساد، وجود، فكرة).
const _minLengthAfterSingleLetter = 4;

/// جذع كلمة مطبَّعة واحدة.
String lightStem(String word) {
  var w = word;
  for (final p in _prefixes) {
    final min = p.length == 1 ? _minLengthAfterSingleLetter : _minLength;
    if (w.startsWith(p) && w.length - p.length >= min) {
      w = w.substring(p.length);
      break;
    }
  }
  for (final s in _suffixes) {
    if (w.endsWith(s) && w.length - s.length >= _minLength) {
      w = w.substring(0, w.length - s.length);
      break;
    }
  }
  return w;
}

/// جذوع كلمات نص مطبَّع مفصولة بمسافة (قيمة عمود `stem`).
String stemNormalized(String normalized) =>
    normalized.isEmpty ? '' : normalized.split(' ').map(lightStem).join(' ');
