// نص المصحف (Tanzil عثماني، حفص) وتجهيزه للمطابقة وللرسم بخط مجمع الملك فهد.
import 'dart:convert';
import 'dart:math';

const basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
const _digits = '٠١٢٣٤٥٦٧٨٩';

String arNum(int n) => n.toString().split('').map((d) => _digits[int.parse(d)]).join();
bool isNum(String w) => RegExp(r'^[٠-٩]+$').hasMatch(w);

final marks = RegExp(r'[ؐ-ًؚ-ٰٟۖ-ۭ࣓-ࣿـ]');
const _fold = {'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي'};

/// هيكل الكلمة للمطابقة: بلا تشكيل، والألفات والهمزات موحّدة ومحذوفة (الرسم العثماني يحذف ألفات كثيرة).
String norm(String w) => w
    .replaceAll(marks, '')
    .split('')
    .map((c) => _fold[c] ?? c)
    .join()
    .replaceAll(RegExp(r'[^ء-ي]'), '')
    .replaceAll(RegExp(r'[اء]'), '');

int letters(String t) => t.replaceAll(marks, '').replaceAll(RegExp(r'[\s٠-٩]'), '').length.clamp(1, 1 << 30);

// Tanzil يرمز بعض العلامات بغير ترميز خط المجمع (QPC)؛ بدون التحويل تظهر دائرة منقطة مكانها
const _staggered = {'ً': 'ٗ', 'ٌ': 'ٞ', 'ٍ': 'ٖ'};
const _qpc = {'۟': 'ْ', 'ْ': 'ۡ', '۪': 'ٜ', '۫': '۬', 'ۣ': 'ۜ'};

String forHafs(String word, String next) {
  final iqlab = next.replaceFirst(RegExp(r'^ـ+'), '').startsWith('ب');
  return word
      .replaceAllMapped(RegExp('([ًٌٍ])[ۭۢ]'),
          (m) => iqlab ? '${m[1]}ۢ' : _staggered[m[1]]!)
      .replaceAllMapped(RegExp('[ْ۪ۣ۟۫]'), (m) => _qpc[m[0]]!);
}

/// تحويل نصوص المقاطع المتتالية إلى ترميز الخط، مع معرفة الكلمة التالية حتى عبر المقاطع.
List<String> textsForFont(List<String> texts, [String tail = '']) {
  final split = texts.map((t) => t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList()).toList();
  final flat = [...split.expand((x) => x), tail];
  final real = [for (var i = 0; i < flat.length; i++) if (flat[i].isNotEmpty && !isNum(flat[i])) i];
  final conv = [...flat];
  for (var k = 0; k < real.length; k++) {
    conv[real[k]] = forHafs(flat[real[k]], k + 1 < real.length ? flat[real[k + 1]] : '');
  }
  var pos = 0;
  return [
    for (final ws in split) () { final s = conv.sublist(pos, pos + ws.length).join(' '); pos += ws.length; return s; }()
  ];
}

/// موضع كلمات المقطع داخل نص الآية كنسبتين (من، إلى) بين 0 و1 بحسب عدد الحروف؛
/// null إن لم يُعثر عليها (نص عُدّل يدوياً).
(double, double)? ayahRange(String ayah, String seg) {
  final aw = ayah.split(' ').where((w) => w.isNotEmpty).toList();
  final sw = seg.split(' ').where((w) => w.isNotEmpty && !isNum(w)).toList();
  if (aw.isEmpty || sw.isEmpty || sw.length > aw.length) return null;
  final an = aw.map(norm).toList(), sn = sw.map(norm).toList();
  var at = -1;
  for (var i = 0; i + sn.length <= an.length && at < 0; i++) {
    var ok = true;
    for (var k = 0; k < sn.length; k++) {
      if (an[i + k] != sn[k]) {
        ok = false;
        break;
      }
    }
    if (ok) at = i;
  }
  if (at < 0) return null;
  final w = [for (final x in aw) letters(x)];
  final total = w.fold(0, (s, x) => s + x);
  final before = w.sublist(0, at).fold(0, (s, x) => s + x);
  final inside = w.sublist(at, at + sn.length).fold(0, (s, x) => s + x);
  return (before / total, (before + inside) / total);
}

final _endPunct = RegExp(r'[.,;:!?،؛؟—–)\]»”"]$');

/// الجزء من الترجمة أو التفسير المقابل لنسبتي الآية (من، إلى): تقسيم تقريبي بحسب الحروف،
/// ويُقرَّب الحد إلى أقرب علامة وقف قريبة فتنتهي القطع عند نهاية عبارة قدر الإمكان.
String sliceTranslation(String tr, double f0, double f1) {
  final t = tr.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final n = t.length;
  if (n == 0 || (f0 <= 0 && f1 >= 1)) return tr;
  int cut(double f) {
    final c = (n * f).round().clamp(0, n);
    if (c <= 0 || c >= n) return c;
    final w = max(1, (n * 0.12).round());
    var best = c, bd = 1 << 30;
    for (var j = max(1, c - w); j <= min(n - 1, c + w); j++) {
      if (_endPunct.hasMatch(t[j - 1]) && (j - c).abs() < bd) {
        best = j;
        bd = (j - c).abs();
      }
    }
    return best;
  }

  final a = min(cut(f0), n - 1);
  var b = cut(f1);
  if (b <= a) b = min(n, a + 1);
  return t.sublist(a, b).join(' ');
}

class Word {
  final int surah, ayah;
  final String text;
  const Word(this.surah, this.ayah, this.text);
}

class Quran {
  final List<String> names;
  final List<List<String>> ayat;
  final List<Word> words = [];
  final List<String> normed = [];
  Map<String, List<int>>? _bigrams;

  Quran(this.names, this.ayat) {
    for (var s = 0; s < ayat.length; s++) {
      for (var a = 0; a < ayat[s].length; a++) {
        for (final w in ayat[s][a].split(' ')) {
          words.add(Word(s + 1, a + 1, w));
          normed.add(norm(w));
        }
      }
    }
  }

  factory Quran.fromJson(String src) {
    final data = jsonDecode(src) as List;
    return Quran([for (final x in data) x[0] as String],
        [for (final x in data) (x[1] as List).cast<String>()]);
  }

  bool sameAyah(int x, int y) => words[x].surah == words[y].surah && words[x].ayah == words[y].ayah;
  bool ayahEnd(int x) => x + 1 >= words.length || !sameAyah(x, x + 1);

  Map<String, List<int>> get bigrams {
    if (_bigrams != null) return _bigrams!;
    final m = <String, List<int>>{};
    for (var j = 0; j < normed.length - 1; j++) {
      final l = m.putIfAbsent('${normed[j]} ${normed[j + 1]}', () => []);
      if (l.length <= 50) l.add(j);
    }
    return _bigrams = m;
  }

  String ayahText(int s, int a) => '${ayat[s - 1][a - 1]} ${arNum(a)}';
  String nextWord(int s, int a) => a < ayat[s - 1].length ? ayat[s - 1][a].split(' ').first : '';
  (String, String?) header(int s) => ('سُورَةُ ${names[s - 1]}', s == 1 || s == 9 ? null : basmala);
}
