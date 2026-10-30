// المزامنة: وحدات النَّفَس من الصوت، ثم تحديد الآيات ومحاذاة نص التعرف مع المصحف، ثم المقاطع.
// منقولة من نسخة الصفحة المختبرة (web/tilawa.html).
import 'dart:math';
import 'dart:typed_data';

import 'quran.dart';

const sr = 16000;

class Segment {
  String text;
  double start, end;
  Segment(this.text, this.start, this.end);
  Segment copy() => Segment(text, start, end);
  Map<String, dynamic> toJson() => {'text': text, 'start': start, 'end': end};
  factory Segment.fromJson(Map<String, dynamic> j) =>
      Segment(j['text'] as String, (j['start'] as num).toDouble(), (j['end'] as num).toDouble());
}

/// فترات الصمت: أهدأ من ذروة التلاوة بـ 32 ديسيبل، أو قريبة من أرضية الضجيج إن كان في التسجيل أصوات محيطة.
(List<(double, double)>, Float32List) silences(Float32List a, {double frame = 0.02, double minLen = 0.25}) {
  final n = (sr * frame).round(), m = a.length ~/ n;
  final db = Float32List(m);
  for (var k = 0; k < m; k++) {
    var s = 0.0;
    for (var i = k * n; i < (k + 1) * n; i++) {
      s += a[i] * a[i];
    }
    db[k] = 10 * log(s / n + 1e-10) / ln10;
  }
  if (m == 0) return (<(double, double)>[], db);
  final sorted = Float32List.fromList(db)..sort();
  double pct(double p) => sorted[min(m - 1, (p / 100 * (m - 1)).floor())];
  final low = pct(5), high = pct(95), th = max(high - 32, low + 0.3 * (high - low));
  final out = <(double, double)>[];
  var st = -1;
  for (var k = 0; k <= m; k++) {
    final q = k < m && db[k] < th;
    if (q && st < 0) {
      st = k;
    } else if (!q && st >= 0) {
      if ((k - st) * frame >= minLen) out.add((st * frame, k * frame));
      st = -1;
    }
  }
  return (out, db);
}

/// وحدات النَّفَس: ما بين وقفتين؛ القصيرة تُضم لما قبلها، والأطول من 28 ث تُقسم عند أهدأ لحظة.
List<List<double>> breathUnits(Float32List a) {
  const frame = 0.02;
  final (q, db) = silences(a, frame: frame);
  final total = a.length / sr;
  final units = <List<double>>[];
  var t = 0.0;
  for (final (s, e) in q) {
    if (s - t > 0.05) units.add([t, s]);
    t = e;
  }
  if (total - t > 0.05) units.add([t, total]);
  final merged = <List<double>>[];
  for (final u in units) {
    if (merged.isNotEmpty &&
        (u[1] - u[0] < 0.6 || u[0] - merged.last[1] < 0.12) &&
        u[1] - merged.last[0] < 28) {
      merged.last[1] = u[1];
    } else {
      merged.add([...u]);
    }
  }
  final out = <List<double>>[];
  for (final u in merged) {
    var s = u[0];
    final e = u[1];
    while (e - s > 28) {
      var best = s + 20, bv = double.infinity;
      for (var x = s + 10; x < s + 28; x += frame) {
        final i = (x / frame).floor();
        if (i < db.length && db[i] < bv) {
          bv = db[i];
          best = x;
        }
      }
      out.add([s, best]);
      s = best;
    }
    out.add([s, e]);
  }
  return out;
}

/// تُجمع الوحدات في كتل حتى maxLen ثانية: Whisper يعالج كل نداء كأنه 30 ث، فالتجميع أسرع؛ لكن sherpa
/// يتأخر في كتابة آخر الكلام فيحتاج صمتاً طويلاً بعده (asr.dart يضيف 8 ث)، فالكتلة لا تتجاوز 12 ث. يرجع [أول وحدة، آخر وحدة].
List<(int, int)> packBlocks(List<List<double>> units, {double maxLen = 12}) {
  final blocks = <(int, int)>[];
  for (var u = 0; u < units.length; u++) {
    if (blocks.isNotEmpty && units[u][1] - units[blocks.last.$1][0] <= maxLen) {
      blocks[blocks.length - 1] = (blocks.last.$1, u);
    } else {
      blocks.add((u, u));
    }
  }
  return blocks;
}

/// موضع التلاوة في المصحف: البداية من أول 40 كلمة والنهاية من آخر 40 (النافذة القصيرة لا تزيحها
/// الكلمات الفائتة أو المكررة كما تزيح نافذة التلاوة كلها).
(int, int)? locate(Quran q, List<String> an) {
  if (an.length <= 60) return _locate(q, an);
  final head = _locate(q, an.sublist(0, 40)), tail = _locate(q, an.sublist(an.length - 40));
  if (head == null || tail == null || tail.$2 < head.$1) return _locate(q, an);
  return (head.$1, tail.$2);
}

(int, int)? _locate(Quran q, List<String> an) {
  final idx = q.bigrams, votes = <int, List<int>>{};
  for (var i = 0; i < an.length - 1; i++) {
    final hits = idx['${an[i]} ${an[i + 1]}'];
    if (hits != null && hits.length <= 50) {
      for (final j in hits) {
        votes.putIfAbsent(j - i, () => []).add(j);
      }
    }
  }
  if (votes.isEmpty) return null;
  int? best;
  var bs = -1;
  for (final d in votes.keys) {
    var s = 0;
    for (var k = -15; k <= 15; k++) {
      s += votes[d + k]?.length ?? 0;
    }
    if (s > bs) {
      bs = s;
      best = d;
    }
  }
  final hits = <int>[for (var k = -15; k <= 15; k++) ...?votes[best! + k]]..sort();
  var lo = max(hits.first - 3, 0), hi = min(hits.last + 4, q.words.length - 1);
  while (lo > 0 && q.sameAyah(lo - 1, lo)) {
    lo--;
  }
  while (hi < q.words.length - 1 && q.sameAyah(hi + 1, hi)) {
    hi++;
  }
  return (lo, hi);
}

double sim(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  final m = a.length, n = b.length;
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      dp[i][j] = a[i - 1] == b[j - 1] ? dp[i - 1][j - 1] + 1 : max(dp[i - 1][j], dp[i][j - 1]);
    }
  }
  return 2 * dp[m][n] / (m + n);
}

/// محاذاة كلمات التعرف مع كلمات المصحف؛ يُسمح بالرجوع للخلف (القارئ يعيد مقطعاً).
List<int?> align(List<String> an, List<String> qn, {double jump = 2.5}) {
  final n = an.length, m = qn.length, mm = m + 1;
  const neg = -1e9;
  final score = Float64List((n + 1) * mm)..fillRange(0, (n + 1) * mm, neg);
  final bi = Int32List((n + 1) * mm)..fillRange(0, (n + 1) * mm, -1);
  final bj = Int32List((n + 1) * mm);
  final bq = Int32List((n + 1) * mm)..fillRange(0, (n + 1) * mm, -1);
  void set(int i, int j, double v, int pi, int pj, int q) {
    final k = i * mm + j;
    if (v > score[k]) {
      score[k] = v;
      bi[k] = pi;
      bj[k] = pj;
      bq[k] = q;
    }
  }

  void skips(int i) {
    for (var j = 1; j <= m; j++) {
      set(i, j, score[i * mm + j - 1] - 0.6, i, j - 1, -1);
    }
  }

  void jumps(int i) {
    var best = neg;
    var arg = -1;
    for (var j = m; j >= 0; j--) {
      set(i, j, best - jump, i, arg, -1);
      if (score[i * mm + j] > best) {
        best = score[i * mm + j];
        arg = j;
      }
    }
  }

  score[0] = 0;
  skips(0);
  for (var i = 1; i <= n; i++) {
    for (var j = 0; j <= m; j++) {
      set(i, j, score[(i - 1) * mm + j] - 0.7, i - 1, j, -1);
      if (j > 0) set(i, j, score[(i - 1) * mm + j - 1] + 2 * sim(an[i - 1], qn[j - 1]) - 1, i - 1, j - 1, j - 1);
    }
    skips(i);
    jumps(i);
    skips(i);
  }
  final match = List<int?>.filled(n, null);
  var i = n, j = 0;
  for (var x = 1; x <= m; x++) {
    if (score[n * mm + x] > score[n * mm + j]) j = x;
  }
  while (bi[i * mm + j] >= 0) {
    final k = i * mm + j, pi = bi[k], pj = bj[k];
    if (pi == i - 1 && bq[k] >= 0) match[i - 1] = bq[k];
    i = pi;
    j = pj;
  }
  return match;
}

/// توزيع كلمات كل كتلة على وحداتها: القطع حيث يتناسب عدد الحروف مع مدة كل وحدة،
/// ويُفضَّل عند نهاية آية أو حيث يرجع القارئ ليعيد مقطعاً.
List<List<String>> splitBlocks(Quran q, List<List<double>> units, List<(int, int)> blocks,
    List<List<String>> blockWords, List<int?> match, int lo) {
  final out = <List<String>>[];
  var w0 = 0;
  for (var k = 0; k < blocks.length; k++) {
    final (u0, u1) = blocks[k];
    final words = blockWords[k], n = words.length, kk = u1 - u0 + 1;
    final ms = [for (var j = 0; j < n; j++) match[w0 + j] == null ? null : match[w0 + j]! + lo];
    w0 += n;
    if (kk == 1 || n == 0) {
      out.add(words);
      for (var i = 1; i < kk; i++) {
        out.add([]);
      }
      continue;
    }
    final l = [0];
    for (final w in words) {
      l.add(l.last + norm(w).length + 1);
    }
    final dur = [for (var u = u0; u <= u1; u++) units[u][1] - units[u][0]];
    final rate = l[n] / dur.reduce((a, b) => a + b);
    double bonus(int p) {
      int? prev, next;
      for (var j = p - 1; j >= 0 && prev == null; j--) {
        prev = ms[j];
      }
      for (var j = p; j < n && next == null; j++) {
        next = ms[j];
      }
      if (prev == null || next == null) return 0;
      if (next <= prev) return 3;
      return q.ayahEnd(prev) ? 1.5 : 0;
    }

    final best = List.generate(kk + 1, (_) => List.filled(n + 1, double.infinity));
    final from = List.generate(kk + 1, (_) => List.filled(n + 1, 0));
    best[0][0] = 0;
    for (var i = 1; i <= kk; i++) {
      for (var p = i; p <= n - (kk - i); p++) {
        for (var a = i - 1; a < p; a++) {
          if (best[i - 1][a] == double.infinity) continue;
          final diff = (l[p] - l[a]) / rate - dur[i - 1];
          final c = best[i - 1][a] + diff * diff / max(dur[i - 1], 1) - (i < kk ? bonus(p) : 0);
          if (c < best[i][p]) {
            best[i][p] = c;
            from[i][p] = a;
          }
        }
      }
    }
    final cuts = [n];
    var p = n;
    for (var i = kk; i > 1; i--) {
      p = from[i][p];
      cuts.insert(0, p);
    }
    var a = 0;
    for (final c in cuts) {
      out.add(words.sublist(a, c));
      a = c;
    }
  }
  return out;
}

class _Run {
  int a, b;
  final double us, ue;
  final int unit;
  _Run(this.a, this.b, this.us, this.ue, this.unit);
}

/// المقاطع: كل وحدة نَفَس مقطع، تُقسم عند نهاية الآية وعند رجوع القارئ للخلف؛
/// والكلمات القليلة التي فاتت التعرف بين مقطعين تُكمل من المصحف.
List<(Segment, int, int)> buildSegments(
    Quran q, List<List<double>> units, List<List<String>> unitWords, List<int?> match, int lo) {
  final runs = <_Run>[];
  var w = 0;
  for (var u = 0; u < units.length; u++) {
    final qs = <int>[];
    for (var k = 0; k < unitWords[u].length; k++, w++) {
      if (match[w] != null) qs.add(match[w]! + lo);
    }
    if (qs.isEmpty) continue;
    var r = _Run(qs[0], qs[0], units[u][0], units[u][1], u);
    runs.add(r);
    for (final x in qs.skip(1)) {
      if (x > r.b) {
        r.b = x;
      } else if (x < r.a || x < r.b - 1) {
        r = _Run(x, x, units[u][0], units[u][1], u);
        runs.add(r);
      }
    }
  }
  for (var k = 1; k < runs.length; k++) {
    final p = runs[k - 1], c = runs[k], gap = c.a - p.b - 1;
    if (gap < 1 || gap > 4) continue;
    if (q.sameAyah(p.b, c.a)) {
      if (p.unit != c.unit) {
        c.a = p.b + 1;
      } else {
        p.b = c.a - 1;
      }
    } else {
      while (p.b + 1 < c.a && q.sameAyah(p.b, p.b + 1)) {
        p.b++;
      }
      while (c.a - 1 > p.b && q.sameAyah(c.a, c.a - 1)) {
        c.a--;
      }
    }
  }
  final segs = <(Segment, int, int)>[];
  final ends = <double>[];
  var k = 0;
  while (k < runs.length) {
    final unit = runs[k].unit, us = runs[k].us, ue = runs[k].ue;
    final pieces = <(int, int)>[];
    for (; k < runs.length && runs[k].unit == unit; k++) {
      var s = runs[k].a;
      for (var x = runs[k].a; x <= runs[k].b; x++) {
        if (x == runs[k].b || !q.sameAyah(x, x + 1)) {
          pieces.add((s, x));
          s = x + 1;
        }
      }
    }
    final lens = [
      for (final (a, b) in pieces) q.words.sublist(a, b + 1).fold(0, (s, x) => s + letters(x.text))
    ];
    final total = lens.reduce((a, b) => a + b);
    var t = us;
    for (var i = 0; i < pieces.length; i++) {
      final (a, b) = pieces[i];
      final last = q.words[b];
      final text = q.words.sublist(a, b + 1).map((x) => x.text).join(' ') +
          (q.ayahEnd(b) ? ' ${arNum(last.ayah)}' : '');
      segs.add((Segment(text, t, 0), last.surah, last.ayah));
      ends.add(ue);
      t += (ue - us) * lens[i] / total;
    }
  }
  for (var i = 0; i < segs.length; i++) {
    final g = segs[i].$1;
    g.end = i + 1 < segs.length ? max(g.start + 0.3, segs[i + 1].$1.start - 0.15) : ends[i] + 0.6;
  }
  return segs;
}

class SyncResult {
  final int surah, from, to;
  final List<Segment> segs;
  SyncResult(this.surah, this.from, this.to, this.segs);
}

/// كل المسار بعد التعرف: يأخذ وحدات النَّفَس وكتلها ونصوص الكتل، ويرجع السورة والمقاطع.
SyncResult? finishSync(Quran q, List<List<double>> units, List<(int, int)> blocks, List<String> blockTexts) {
  final blockWords = [for (final t in blockTexts) t.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList()];
  final an = blockWords.expand((x) => x).map(norm).toList();
  final span = locate(q, an);
  if (span == null) return null;
  final (lo, hi) = span;
  final match = align(an, q.normed.sublist(lo, hi + 1));
  final unitWords = splitBlocks(q, units, blocks, blockWords, match, lo);
  final segs = buildSegments(q, units, unitWords, match, lo);
  if (segs.isEmpty) return null;
  final count = <int, int>{};
  for (final s in segs) {
    count[s.$2] = (count[s.$2] ?? 0) + 1;
  }
  final surah = count.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final mine = segs.where((s) => s.$2 == surah).toList();
  return SyncResult(surah, mine.map((s) => s.$3).reduce(min), mine.map((s) => s.$3).reduce(max),
      [for (final s in mine) Segment(s.$1.text, _r(s.$1.start), _r(s.$1.end))]);
}

double _r(double x) => (x * 100).round() / 100;
