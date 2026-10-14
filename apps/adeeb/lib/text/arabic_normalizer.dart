/// التطبيع العربي الموحّد (ARCHITECTURE §6): دالة واحدة للفهرسة والاستعلام
/// والتحقق من الاقتباس. Dart صافٍ.
///
/// 1. حذف التشكيل (U+064B–U+065F، ومنها الشدة والسكون وعلامات الهمزة
///    والمدة المركّبة U+0653–U+0655)، والألف الخنجرية (U+0670)، وعلامات
///    القرآن (U+0610–U+061A وU+06D6–U+06ED)، والتطويل (U+0640)، ومحارف
///    الاتجاه والوصل غير المرئية.
/// 2. توحيد: أ إ آ ٱ ٲ ٳ ← ا، ؤ ← و، ئ ← ي، ة ← ه، ى ی ← ي، ک ← ك.
///    الهمزة المفردة ء تبقى.
/// 3. كل ما ليس حرفاً أو رقماً ← مسافة، ثم ضغط المسافات وحذف الأطراف.
/// 4. الأرقام الهندية والفارسية ← لاتينية، والحروف اللاتينية صغيرة.
///
/// **NFC:** لا يلزم تطبيقه قبل الدالة: الشكل المفكوك للهمزات والمدة (حرف +
/// U+0653/U+0654/U+0655) يعطي النتيجة نفسها لأن العلامة تُحذف والحرف الأساسي
/// هو ناتج التوحيد نفسه (أ = ا+ٔ ← ا، ؤ = و+ٔ ← و، ئ = ي+ٔ ← ي).
library;

/// النص المطبَّع مع خريطة مواضعه في النص الأصلي (بوحدات UTF-16).
class NormalizedText {
  const NormalizedText(this.text, this.starts, this.ends);

  final String text;

  /// لكل محرف في [text]: بداية المحرف الأصلي المقابل.
  final List<int> starts;

  /// لكل محرف في [text]: نهاية حصرية تشمل التشكيل والتطويل التابعين له.
  final List<int> ends;
}

/// يطبّع [input] للفهرسة أو الاستعلام أو المقارنة.
String normalizeArabic(String input) => _normalize(input, null).text;

/// مثل [normalizeArabic] مع خريطة المواضع لإعادة التظليل على النص الأصلي.
NormalizedText normalizeArabicWithMap(String input) =>
    _normalize(input, (starts: <int>[], ends: <int>[]));

const _space = 0x20;

/// نوع المحرف: محذوف بلا أثر، أو فاصل (مسافة)، أو محرف ناتج.
const _drop = -1;
const _separator = -2;

int _classify(int c) {
  // حروف لاتينية وأرقام.
  if (c >= 0x61 && c <= 0x7A) return c;
  if (c >= 0x41 && c <= 0x5A) return c + 0x20;
  if (c >= 0x30 && c <= 0x39) return c;
  if (c < 0x0600) return _separator;
  // التشكيل وعلامات القرآن والتطويل.
  if (c >= 0x064B && c <= 0x065F) return _drop;
  if (c == 0x0670 || c == 0x0640) return _drop;
  if (c >= 0x0610 && c <= 0x061A) return _drop;
  if (c >= 0x06D6 && c <= 0x06ED) return _drop;
  // الأرقام الهندية (٠-٩) والفارسية (۰-۹).
  if (c >= 0x0660 && c <= 0x0669) return 0x30 + c - 0x0660;
  if (c >= 0x06F0 && c <= 0x06F9) return 0x30 + c - 0x06F0;
  switch (c) {
    case 0x0622 || 0x0623 || 0x0625 || 0x0671 || 0x0672 || 0x0673:
      return 0x0627; // ا
    case 0x0624:
      return 0x0648; // و
    case 0x0626 || 0x0649 || 0x06CC:
      return 0x064A; // ي
    case 0x0629:
      return 0x0647; // ه
    case 0x06A9:
      return 0x0643; // ك
  }
  // الحروف العربية الأساسية والممتدة.
  if (c >= 0x0621 && c <= 0x063A) return c;
  if (c >= 0x0641 && c <= 0x064A) return c;
  if (c >= 0x0674 && c <= 0x06D3) return c;
  if (c >= 0x06FA && c <= 0x06FC) return c;
  // محارف الوصل والفصل والاتجاه غير المرئية لا تقطع الكلمة.
  if (c == 0x200C || c == 0x200D || c == 0xFEFF) return _drop;
  if (c >= 0x200E && c <= 0x200F) return _drop;
  if (c >= 0x202A && c <= 0x202E) return _drop;
  if (c >= 0x2066 && c <= 0x2069) return _drop;
  return _separator;
}

NormalizedText _normalize(
  String input,
  ({List<int> starts, List<int> ends})? map,
) {
  final out = <int>[];
  for (var i = 0; i < input.length; i++) {
    final kind = _classify(input.codeUnitAt(i));
    if (kind == _drop) {
      // العلامة تتبع آخر حرف ناتج (لتظليل الكلمة بتشكيلها).
      if (map != null && out.isNotEmpty && out.last != _space) {
        map.ends[map.ends.length - 1] = i + 1;
      }
      continue;
    }
    if (kind == _separator) {
      if (out.isNotEmpty && out.last != _space) {
        out.add(_space);
        map?.starts.add(i);
        map?.ends.add(i + 1);
      }
      continue;
    }
    out.add(kind);
    map?.starts.add(i);
    map?.ends.add(i + 1);
  }
  if (out.isNotEmpty && out.last == _space) {
    out.removeLast();
    map?.starts.removeLast();
    map?.ends.removeLast();
  }
  return NormalizedText(
    String.fromCharCodes(out),
    map?.starts ?? const [],
    map?.ends ?? const [],
  );
}
