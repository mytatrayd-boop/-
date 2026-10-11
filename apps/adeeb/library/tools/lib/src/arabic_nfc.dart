/// تطبيع NFC محصور في نطاق الكتابة العربية (Dart لا يوفّر NFC مدمجاً،
/// ولا نضيف حزمة غير معتمدة). يغطي:
/// - إعادة الترتيب القانوني للحركات العربية حسب صنف الدمج (ccc).
/// - الدمج القانوني: ا+ٓ←آ، ا+ٔ←أ، ا+ٕ←إ، و+ٔ←ؤ، ي+ٔ←ئ، ه‍+ٔ←ۀ، ہ+ٔ←ۂ، ے+ٔ←ۓ.
/// أي علامة دمج خارج هذا الجدول تُعدّ غير مدعومة ([unsupportedMarks]).
library;

/// صنف الدمج القانوني (Canonical_Combining_Class) للعلامات العربية.
int arabicCcc(int cp) {
  if (cp >= 0x0610 && cp <= 0x0617) return 230;
  switch (cp) {
    case 0x0618:
      return 30;
    case 0x0619:
      return 31;
    case 0x061A:
      return 32;
    case 0x064B:
      return 27;
    case 0x064C:
      return 28;
    case 0x064D:
      return 29;
    case 0x064E:
      return 30;
    case 0x064F:
      return 31;
    case 0x0650:
      return 32;
    case 0x0651:
      return 33;
    case 0x0652:
      return 34;
    case 0x0653:
    case 0x0654:
      return 230;
    case 0x0655:
    case 0x0656:
      return 220;
    case 0x065C:
    case 0x065F:
      return 220;
    case 0x0670:
      return 35;
    case 0x06E3:
    case 0x06EA:
    case 0x06ED:
      return 220;
  }
  if (cp >= 0x0657 && cp <= 0x065B) return 230;
  if (cp == 0x065D || cp == 0x065E) return 230;
  if (cp >= 0x06D6 && cp <= 0x06DC) return 230;
  if (cp >= 0x06DF && cp <= 0x06E2) return 230;
  if (cp == 0x06E4 || cp == 0x06E7 || cp == 0x06E8) return 230;
  if (cp == 0x06EB || cp == 0x06EC) return 230;
  return 0;
}

const Map<int, Map<int, int>> _compose = {
  0x0627: {0x0653: 0x0622, 0x0654: 0x0623, 0x0655: 0x0625},
  0x0648: {0x0654: 0x0624},
  0x064A: {0x0654: 0x0626},
  0x06D5: {0x0654: 0x06C0},
  0x06C1: {0x0654: 0x06C2},
  0x06D2: {0x0654: 0x06D3},
};

/// علامات دمج عامة (غير عربية) لا يعالجها هذا التطبيع.
bool _isForeignCombining(int cp) =>
    (cp >= 0x0300 && cp <= 0x036F) ||
    (cp >= 0x1AB0 && cp <= 0x1AFF) ||
    (cp >= 0x1DC0 && cp <= 0x1DFF) ||
    (cp >= 0x20D0 && cp <= 0x20FF) ||
    (cp >= 0xFE20 && cp <= 0xFE2F);

/// العلامات غير المدعومة الموجودة في النص (فارغة = النص قابل للتطبيع هنا).
Set<int> unsupportedMarks(String s) =>
    s.runes.where(_isForeignCombining).toSet();

/// يعيد النص بصيغة NFC (في نطاق العربية).
String arabicNfc(String s) {
  final input = s.runes.toList();
  final out = <int>[];
  var i = 0;
  while (i < input.length) {
    final cp = input[i];
    if (arabicCcc(cp) != 0) {
      // علامة بلا حرف أساس قبلها في هذا المقطع: ترتَّب مع ما يليها.
      final marks = <int>[];
      while (i < input.length && arabicCcc(input[i]) != 0) {
        marks.add(input[i]);
        i++;
      }
      out.addAll(_stableSortByCcc(marks));
      continue;
    }
    var starter = cp;
    i++;
    final marks = <int>[];
    while (i < input.length && arabicCcc(input[i]) != 0) {
      marks.add(input[i]);
      i++;
    }
    final sorted = _stableSortByCcc(marks);
    // الدمج: علامة غير محجوبة (لا علامة قبلها بصنف >= صنفها) تُدمج في الأساس.
    final remaining = <int>[];
    var lastCcc = -1;
    for (final m in sorted) {
      final c = arabicCcc(m);
      final composed = _compose[starter]?[m];
      final blocked = remaining.isNotEmpty && lastCcc >= c;
      if (composed != null && !blocked) {
        starter = composed;
      } else {
        remaining.add(m);
        lastCcc = c;
      }
    }
    out.add(starter);
    out.addAll(remaining);
  }
  return String.fromCharCodes(out);
}

List<int> _stableSortByCcc(List<int> marks) {
  final indexed = List.generate(marks.length, (i) => i);
  indexed.sort((a, b) {
    final d = arabicCcc(marks[a]).compareTo(arabicCcc(marks[b]));
    return d != 0 ? d : a.compareTo(b);
  });
  return [for (final i in indexed) marks[i]];
}

bool isArabicNfc(String s) => arabicNfc(s) == s;
