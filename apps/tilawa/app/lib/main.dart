// تلاوة: ارفع تلاوة ← تعرّف تلقائي على الآيات وتوقيتها ← تحرير بالخط الزمني ← فيديو 1080×1920.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:just_audio/just_audio.dart';

import 'asr.dart';
import 'editor.dart';
import 'look.dart';
import 'media.dart';
import 'quran.dart';
import 'sync.dart';

void main() => runApp(const TilawaApp());

class TilawaApp extends StatelessWidget {
  const TilawaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'تلاوة',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6B55), brightness: Brightness.dark, useMaterial3: true),
        home: const Home(),
      );
}

const presets = ['ليل ونجوم', 'غروب', 'فجر', 'زمردي', 'أسود'];
const swatches = [Colors.white, Color(0xFFF3E3B5), Color(0xFFE8C66A), Color(0xFFBFE3FF), Color(0xFFD7F5E6)];

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  final m = EditorModel();
  final look = Look();
  final player = AudioPlayer();
  late final TabController tabs = TabController(length: 4, vsync: this);
  Quran? quran;
  Asr? asr;
  String? audioPath;
  Float32List? audio16;
  int surah = 70, from = 1, to = 5;
  final bgs = <Bg>[];
  String status = '';
  double? progress;
  bool busy = false, splitting = false;
  final textCtl = TextEditingController();
  final addAyahCtl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/quran.json').then((s) => setState(() => quran = Quran.fromJson(s)));
    _presetBg(0).then((b) => setState(() => bgs.add(b)));
    player.positionStream.listen((p) {
      if (!player.playing) return;
      final t = p.inMilliseconds / 1000;
      if (t >= m.trimEnd) {
        player.pause();
        if (m.tapIndex != null) m.tapStop(t);
      }
      m.playhead = t;
      if (!mounted) return;
      final w = MediaQuery.of(context).size.width;
      if (t > m.view + w / m.pps * 0.85 || t < m.view) m.view = (t - w / m.pps * 0.15).clamp(0, m.duration);
      m.changed();
    });
    player.playingStream.listen((_) => setState(() {}));
    m.addListener(_syncText);
  }

  void _syncText() {
    final g = m.sel;
    if (g != null && textCtl.text != g.text && !textCtlFocused) textCtl.text = g.text;
  }

  bool get textCtlFocused => FocusManager.instance.primaryFocus?.context?.widget is EditableText;

  Future<Bg> _presetBg(int i) async {
    final f = File('${(await workDir()).path}/bg$i.jpg');
    if (!f.existsSync()) {
      final d = await rootBundle.load('assets/bg$i.jpg');
      await f.writeAsBytes(d.buffer.asUint8List());
    }
    return Bg(f.path, presets[i]);
  }

  // ── الملف الصوتي والتعرف ──
  Future<void> pickAudio() async {
    final path = (await FilePicker.pickFile(type: FileType.any))?.path;
    if (path == null) return;
    setState(() {
      busy = true;
      status = 'قراءة الملف…';
    });
    try {
      final a = await decode16k(path);
      await player.setFilePath(path);
      audioPath = path;
      audio16 = a;
      m.setAudio(a);
      _distribute();
      setState(() => status = '');
      await autoSync();
    } catch (e) {
      setState(() => status = 'تعذرت قراءة الملف الصوتي.');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> autoSync() async {
    final a = audio16, q = quran;
    if (a == null || q == null) return;
    setState(() {
      busy = true;
      progress = 0;
      status = 'تجهيز نموذج التعرف…';
    });
    try {
      asr ??= await Asr.start();
      final units = breathUnits(a), blocks = packBlocks(units), texts = <String>[];
      for (var k = 0; k < blocks.length; k++) {
        setState(() {
          status = 'التعرف على الصوت: ${k + 1} من ${blocks.length}';
          progress = k / blocks.length;
        });
        final s = (units[blocks[k].$1][0] * sr).floor(), e = (units[blocks[k].$2][1] * sr).ceil();
        texts.add(await asr!.transcribe(Float32List.sublistView(a, s, e.clamp(s, a.length))));
      }
      final r = finishSync(q, units, blocks, texts);
      if (r == null) {
        setState(() => status = 'لم أتعرف على الآيات. اختر السورة والآيات من تبويب «الآيات».');
        return;
      }
      surah = r.surah;
      from = r.from;
      to = r.to;
      m.setSegments(r.segs);
      setState(() => status = 'سورة ${q.names[r.surah - 1]}، الآيات $from–$to، ${r.segs.length} مقطعاً.');
    } catch (e) {
      setState(() => status = 'تعذر التعرف: $e');
    } finally {
      setState(() {
        busy = false;
        progress = null;
      });
    }
  }

  void _distribute() {
    final q = quran;
    if (q == null) return;
    final n = q.ayat[surah - 1].length;
    from = from.clamp(1, n);
    to = to.clamp(from, n);
    final texts = [for (var a = from; a <= to; a++) q.ayahText(surah, a)];
    final total = texts.fold(0, (s, t) => s + letters(t));
    final span = m.duration > 0 ? m.duration : 5.0 * texts.length;
    var t = 0.0;
    m.setSegments([
      for (final x in texts) () { final d = span * letters(x) / total; final g = Segment(x, t, t + d - 0.15); t += d; return g; }()
    ]);
  }

  // ── التشغيل والمزامنة بالنقر ──
  Future<void> togglePlay() async {
    if (audioPath == null) return;
    if (player.playing) {
      await player.pause();
    } else {
      await player.seek(Duration(milliseconds: (m.playhead * 1000).round()));
      player.play();
    }
  }

  Future<void> toggleTap() async {
    if (m.tapIndex != null) {
      m.tapStop(m.playhead);
      await player.pause();
    } else {
      m.tapStart();
      if (m.tapIndex == null) return;
      await player.seek(Duration(milliseconds: (m.playhead * 1000).round()));
      player.play();
    }
    setState(() {});
  }

  // ── الإنتاج ──
  Future<void> export() async {
    final q = quran, a = audioPath;
    if (q == null || a == null) return;
    final list = m.valid;
    if (list.isEmpty) return;
    final (name, bas) = q.header(surah);
    setState(() {
      busy = true;
      progress = 0;
      status = 'جارٍ إنتاج الفيديو…';
    });
    try {
      final end = m.trimEnd < m.duration ? m.trimEnd : (list.last.end + 0.8).clamp(0.0, m.duration);
      final out = await renderVideo(
        audio: a,
        segs: list,
        texts: textsForFont([for (final g in list) g.text], q.nextWord(surah, to)),
        bgs: look.manyBgs ? bgs : [bgs.first],
        look: look,
        headerName: look.showName ? name : null,
        headerBasmala: look.showBasmala ? bas : null,
        trimStart: m.trimStart,
        trimEnd: end,
        onProgress: (p) => setState(() => progress = p),
      );
      await Gal.putVideo(out, album: 'تلاوة');
      setState(() => status = 'حُفظ الفيديو في معرض الصور (ألبوم «تلاوة»).');
    } catch (e) {
      setState(() => status = 'تعذر الإنتاج: $e');
    } finally {
      setState(() {
        busy = false;
        progress = null;
      });
    }
  }

  // ── الواجهة ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تلاوة'), actions: [
        IconButton(onPressed: busy ? null : pickAudio, icon: const Icon(Icons.audio_file), tooltip: 'اختر تلاوة'),
        if (audioPath != null)
          FilledButton.icon(onPressed: busy ? null : export, icon: const Icon(Icons.movie), label: const Text('أنتج')),
        const SizedBox(width: 8),
      ]),
      body: audioPath == null ? _welcome() : _editor(),
    );
  }

  Widget _welcome() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('ارفع تلاوة، فيتعرف التطبيق على الآيات ويوقّتها، ثم تعدّل بالخط الزمني وتنتج الفيديو.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: busy || quran == null ? null : pickAudio, icon: const Icon(Icons.audio_file), label: const Text('اختر ملف التلاوة')),
            if (status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text(status)),
          ]),
        ),
      );

  Widget _editor() => Column(children: [
        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Center(child: _preview()))),
        if (status.isNotEmpty || progress != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              if (progress != null) LinearProgressIndicator(value: progress),
              Text(status, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        Directionality(textDirection: TextDirection.ltr, child: Timeline(m)),
        _toolbar(),
        TabBar(controller: tabs, tabs: const [Tab(text: 'المقطع'), Tab(text: 'الآيات'), Tab(text: 'الخلفية'), Tab(text: 'النص')]),
        SizedBox(
          height: 230,
          child: TabBarView(controller: tabs, children: [_segTab(), _ayatTab(), _bgTab(), _textTab()]),
        ),
      ]);

  Widget _preview() => AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ListenableBuilder(
            listenable: m,
            builder: (context, _) {
              final q = quran;
              final t = m.playhead;
              final cur = m.valid.where((g) => t >= g.start && t <= g.end).toList();
              final bg = bgs.isEmpty ? null : bgs[_bgIndexAt(t)];
              String? text;
              if (q != null && cur.isNotEmpty) text = textsForFont([cur.first.text], q.nextWord(surah, to)).first;
              final (name, bas) = q?.header(surah) ?? ('', null);
              return Stack(fit: StackFit.expand, children: [
                if (bg != null)
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: look.blur / 4, sigmaY: look.blur / 4),
                    child: Image.file(File(bg.preview), fit: BoxFit.cover),
                  ),
                Container(color: Colors.black.withValues(alpha: look.dim)),
                FittedBox(
                  child: SizedBox(
                    width: vw,
                    height: vh,
                    child: CustomPaint(painter: _LayerPainter((c) {
                      paintHeader(c, look.showName ? name : null, look.showBasmala ? bas : null, look);
                      if (text != null) paintText(c, text, look);
                    })),
                  ),
                ),
              ]);
            },
          ),
        ),
      );

  int _bgIndexAt(double t) {
    if (!look.manyBgs || bgs.length < 2) return 0;
    final pts = bgSchedule(bgs.length, m.trimEnd - m.trimStart, m.valid, look);
    var k = 0;
    for (var i = 0; i < pts.length; i++) {
      if (pts[i] <= t - m.trimStart) k = i;
    }
    return k % bgs.length;
  }

  Widget _toolbar() => ListenableBuilder(
        listenable: m,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton.filled(onPressed: togglePlay, icon: Icon(player.playing ? Icons.pause : Icons.play_arrow)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(fmtTime(m.playhead), textDirection: TextDirection.ltr)),
            IconButton(onPressed: () => setState(() => m.pps = (m.pps / 1.5).clamp(8, 400)), icon: const Icon(Icons.zoom_out)),
            IconButton(onPressed: () => setState(() => m.pps = (m.pps * 1.5).clamp(8, 400)), icon: const Icon(Icons.zoom_in)),
            IconButton(onPressed: m.canUndo ? m.undo : null, icon: const Icon(Icons.undo), tooltip: 'تراجع'),
            const Spacer(),
            if (m.tapIndex != null)
              FilledButton(onPressed: () => m.tap(m.playhead), child: const Text('التالي ⏭')),
            TextButton(onPressed: toggleTap, child: Text(m.tapIndex != null ? 'إنهاء' : '🎯 بالنقر')),
          ]),
        ),
      );

  Widget _pad(List<Widget> c) => ListView(padding: const EdgeInsets.all(12), children: c);
  Widget _wrap(List<Widget> c) => Wrap(spacing: 8, runSpacing: 8, children: c);

  Widget _segTab() => ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          final g = m.sel;
          if (g == null) return const Center(child: Text('اضغط مقطعاً في الخط الزمني لتحريره.'));
          return _pad([
            Text('${fmtTime(g.start)} ← ${fmtTime(g.end)}', textDirection: TextDirection.ltr),
            TextField(
              controller: textCtl,
              maxLines: 2,
              style: const TextStyle(fontSize: 18),
              onTap: m.checkpoint,
              onChanged: (v) {
                g.text = v.trim();
                m.changed();
              },
            ),
            const SizedBox(height: 8),
            _wrap([
              OutlinedButton(onPressed: m.setStartHere, child: const Text('البداية هنا')),
              OutlinedButton(onPressed: m.setEndHere, child: const Text('النهاية هنا')),
              OutlinedButton(onPressed: () => setState(() => splitting = !splitting), child: const Text('✂️ قسّم')),
              OutlinedButton(onPressed: m.mergeNext, child: const Text('ادمج مع التالي')),
              OutlinedButton(onPressed: m.duplicate, child: const Text('🔁 كرّر')),
              OutlinedButton(onPressed: m.delete, child: const Text('🗑 احذف')),
            ]),
            if (splitting) ...[
              const SizedBox(height: 8),
              const Text('اختر الكلمة التي يبدأ بها الجزء الثاني:'),
              _wrap([
                for (final (i, w) in splitWords(g.text).indexed)
                  if (i > 0) ActionChip(label: Text(w.replaceAll(marks, '')), onPressed: () { m.splitAt(i); setState(() => splitting = false); }),
              ]),
            ],
          ]);
        },
      );

  Widget _ayatTab() {
    final q = quran;
    if (q == null) return const SizedBox();
    final n = q.ayat[surah - 1].length;
    return StatefulBuilder(builder: (context, set) => _pad([
          FilledButton.icon(onPressed: busy ? null : autoSync, icon: const Icon(Icons.auto_fix_high), label: const Text('تعرّف تلقائياً من جديد')),
          const SizedBox(height: 8),
          DropdownButton<int>(
            isExpanded: true,
            value: surah,
            items: [for (var i = 1; i <= 114; i++) DropdownMenuItem(value: i, child: Text('$i. ${q.names[i - 1]}'))],
            onChanged: (v) => setState(() { surah = v!; from = 1; to = q.ayat[v - 1].length.clamp(1, 5); }),
          ),
          Row(children: [
            Expanded(child: _numField('من آية', from, 1, n, (v) => setState(() => from = v))),
            const SizedBox(width: 8),
            Expanded(child: _numField('إلى آية', to, from, n, (v) => setState(() => to = v))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _distribute, child: const Text('توزيع تقريبي')),
          ]),
          const Divider(),
          Row(children: [
            Expanded(child: TextField(controller: addAyahCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم آية لإضافتها عند المؤشر'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () {
              final a = int.tryParse(addAyahCtl.text);
              if (a != null && a >= 1 && a <= n) m.addAt(q.ayahText(surah, a));
            }, child: const Text('+ أضف')),
          ]),
          const Divider(),
          _wrap([
            OutlinedButton(onPressed: m.trimBefore, child: const Text('✂️ احذف ما قبل المؤشر')),
            OutlinedButton(onPressed: m.trimAfter, child: const Text('احذف ما بعد المؤشر ✂️')),
            TextButton(onPressed: m.resetTrim, child: const Text('إلغاء القص')),
          ]),
        ]));
  }

  Widget _numField(String label, int v, int lo, int hi, void Function(int) on) => TextFormField(
        key: ValueKey('$label$v$surah'),
        initialValue: '$v',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (s) {
          final x = int.tryParse(s);
          if (x != null && x >= lo && x <= hi) on(x);
        },
      );

  Widget _slider(String label, double v, double lo, double hi, void Function(double) on, {int div = 20}) => Row(children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(child: Slider(value: v.clamp(lo, hi), min: lo, max: hi, divisions: div, label: v.toStringAsFixed(2), onChanged: (x) => setState(() => on(x)))),
      ]);

  Widget _bgTab() => _pad([
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('خلفية واحدة')), ButtonSegment(value: true, label: Text('عدة خلفيات تتبدّل'))],
          selected: {look.manyBgs},
          onSelectionChanged: (s) => setState(() {
            look.manyBgs = s.first;
            if (!look.manyBgs && bgs.length > 1) bgs.removeRange(1, bgs.length);
          }),
        ),
        const SizedBox(height: 8),
        _wrap([
          for (var i = 0; i < presets.length; i++)
            FilterChip(
              label: Text(presets[i]),
              selected: bgs.any((b) => b.name == presets[i]),
              onSelected: (_) async {
                final b = await _presetBg(i);
                setState(() {
                  final at = bgs.indexWhere((x) => x.name == b.name);
                  if (!look.manyBgs) { bgs..clear()..add(b); } else if (at >= 0) { if (bgs.length > 1) bgs.removeAt(at); } else { bgs.add(b); }
                });
              },
            ),
          ActionChip(avatar: const Icon(Icons.add_photo_alternate, size: 18), label: const Text('من المعرض'), onPressed: () async {
            final files = look.manyBgs
                ? await FilePicker.pickFiles(type: FileType.media)
                : [?(await FilePicker.pickFile(type: FileType.media))];
            final added = <Bg>[];
            for (final f in files.where((f) => f.path != null)) {
              final v = isVideo(f.path!);
              added.add(Bg(f.path!, f.name, video: v, thumb: v ? await videoThumb(f.path!) : null));
            }
            setState(() { if (!look.manyBgs) bgs.clear(); bgs.addAll(look.manyBgs ? added : added.take(1)); });
          }),
        ]),
        if (look.manyBgs && bgs.length > 1) ...[
          Text('المختارة: ${bgs.map((b) => b.name).join('، ')}', style: const TextStyle(fontSize: 12)),
          DropdownButton<String>(value: look.bgChange, items: const [
            DropdownMenuItem(value: 'time', child: Text('تتبدّل كل عدد من الثواني')),
            DropdownMenuItem(value: 'segment', child: Text('تتبدّل مع كل مقطع')),
          ], onChanged: (v) => setState(() => look.bgChange = v!)),
          if (look.bgChange == 'time') _slider('كل ${look.bgEvery.round()} ث', look.bgEvery, 3, 30, (x) => look.bgEvery = x, div: 27),
          DropdownButton<String>(value: look.transition, items: const [
            DropdownMenuItem(value: 'fade', child: Text('انتقال: تلاشٍ')),
            DropdownMenuItem(value: 'fadeblack', child: Text('انتقال: عبر الأسود')),
            DropdownMenuItem(value: 'slideright', child: Text('انتقال: انزلاق')),
            DropdownMenuItem(value: 'circleopen', child: Text('انتقال: دائرة')),
            DropdownMenuItem(value: 'none', child: Text('بلا انتقال')),
          ], onChanged: (v) => setState(() => look.transition = v!)),
        ],
        _slider('تعتيم', look.dim, 0, 0.8, (x) => look.dim = x, div: 16),
        _slider('تضبيب', look.blur, 0, 20, (x) => look.blur = x),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('تقريب بطيء للصور'), value: look.zoom, onChanged: (v) => setState(() => look.zoom = v)),
      ]);

  Widget _textTab() => _pad([
        _slider('حجم الخط', look.fontSize, 30, 120, (x) => look.fontSize = x, div: 90),
        _slider('الموضع', look.textY, 0.15, 0.9, (x) => look.textY = x, div: 75),
        _slider('عرض السطر', look.width, 0.5, 0.95, (x) => look.width = x, div: 45),
        _slider('تباعد الأسطر', look.lineGap, 1.3, 2.6, (x) => look.lineGap = x, div: 13),
        _slider('الظل', look.shadow, 0, 1, (x) => look.shadow = x),
        _slider('الظهور والاختفاء', look.fade, 0, 1, (x) => look.fade = x),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'right', label: Text('يمين')), ButtonSegment(value: 'center', label: Text('توسيط')), ButtonSegment(value: 'left', label: Text('يسار'))],
          selected: {look.align},
          onSelectionChanged: (s) => setState(() => look.align = s.first),
        ),
        const SizedBox(height: 8),
        Row(children: [const Text('لون النص  '), for (final c in swatches) _swatch(c, look.color, (x) => look.color = x)]),
        const Divider(),
        DropdownButton<String>(value: look.headerMode, items: const [
          DropdownMenuItem(value: 'mushaf', child: Text('الترويسة: إطار المصحف وبسملة مزخرفة')),
          DropdownMenuItem(value: 'basmala', child: Text('الترويسة: بسملة مزخرفة')),
          DropdownMenuItem(value: 'plain', child: Text('الترويسة: نص عادي')),
        ], onChanged: (v) => setState(() => look.headerMode = v!)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('اسم السورة'), value: look.showName, onChanged: (v) => setState(() => look.showName = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('البسملة'), value: look.showBasmala, onChanged: (v) => setState(() => look.showBasmala = v)),
        _slider('حجم الترويسة', look.headerSize, 24, 90, (x) => look.headerSize = x, div: 66),
        _slider('موضع الترويسة', look.headerY, 0.03, 0.4, (x) => look.headerY = x, div: 37),
        Row(children: [const Text('لون الترويسة  '), for (final c in swatches) _swatch(c, look.headerColor, (x) => look.headerColor = x)]),
      ]);

  Widget _swatch(Color c, Color current, void Function(Color) on) => GestureDetector(
        onTap: () => setState(() => on(c)),
        child: Container(
          margin: const EdgeInsets.all(4),
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: current == c ? Colors.tealAccent : Colors.grey, width: current == c ? 3 : 1)),
        ),
      );
}

class _LayerPainter extends CustomPainter {
  final void Function(Canvas) draw;
  _LayerPainter(this.draw);
  @override
  void paint(Canvas canvas, Size size) => draw(canvas);
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
