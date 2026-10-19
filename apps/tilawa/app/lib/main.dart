// تلاوة: ارفع تلاوة ← تعرّف تلقائي على الآيات وتوقيتها ← تحرير على طريقة CapCut ← فيديو 1080×1920.
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
import 'preview.dart';
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
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF4FC3DC),
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF101010),
          useMaterial3: true,
        ),
        home: const Home(),
      );
}

const presets = ['ليل ونجوم', 'غروب', 'فجر', 'زمردي', 'أسود'];
const swatches = [Colors.white, Color(0xFFF3E3B5), Color(0xFFE8C66A), Color(0xFFBFE3FF), Color(0xFFD7F5E6)];
const accent = Color(0xFF55C7DE);

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  final m = EditorModel();
  final look = Look();
  final player = AudioPlayer();
  final ui0 = ValueNotifier(0); // يعيد بناء اللوحات السفلية عند التغيير
  Quran? quran;
  Asr? asr;
  String? audioPath;
  Float32List? audio16;
  int surah = 70, from = 1, to = 5;
  final bgs = <Bg>[];
  String status = '';
  double? progress;
  bool busy = false;

  void refresh([VoidCallback? fn]) {
    setState(fn ?? () {});
    ui0.value++;
  }

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/quran.json').then((s) => refresh(() => quran = Quran.fromJson(s)));
    _presetBg(0).then((b) => refresh(() => bgs.add(b)));
    // كل إطار أثناء التشغيل: المؤشر يتبع الصوت، ويقفز فوق الأجزاء المحذوفة
    createTicker((_) {
      if (!player.playing) return;
      final t = player.position.inMilliseconds / 1000;
      final skip = m.skipCut(t);
      if (skip != null) player.seek(Duration(milliseconds: (skip * 1000).round()));
      if (t >= m.duration - 0.05) {
        player.pause();
        if (m.tapIndex != null) m.tapStop(t);
      }
      m.playhead = t;
      m.changed();
    }).start();
    player.playingStream.listen((_) => refresh());
    m.addListener(() => ui0.value++);
  }

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
    refresh(() {
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
      refresh(() => status = '');
      await autoSync();
    } catch (e) {
      refresh(() => status = 'تعذرت قراءة الملف الصوتي.');
    } finally {
      refresh(() => busy = false);
    }
  }

  Future<void> autoSync() async {
    final a = audio16, q = quran;
    if (a == null || q == null) return;
    refresh(() {
      busy = true;
      progress = 0;
      status = 'تجهيز نموذج التعرف…';
    });
    try {
      asr ??= await Asr.start();
      final units = breathUnits(a), blocks = packBlocks(units), texts = <String>[];
      for (var k = 0; k < blocks.length; k++) {
        refresh(() {
          status = 'التعرف على الآيات ${((k / blocks.length) * 100).round()}٪';
          progress = k / blocks.length;
        });
        final s = (units[blocks[k].$1][0] * sr).floor(), e = (units[blocks[k].$2][1] * sr).ceil();
        texts.add(await asr!.transcribe(Float32List.sublistView(a, s, e.clamp(s, a.length))));
      }
      final r = finishSync(q, units, blocks, texts);
      if (r == null) {
        refresh(() => status = 'لم أتعرف على الآيات. اختر السورة والآيات من «الآيات».');
        return;
      }
      surah = r.surah;
      from = r.from;
      to = r.to;
      m.setSegments(r.segs);
      refresh(() => status = 'سورة ${q.names[r.surah - 1]}، الآيات $from–$to');
      Future.delayed(const Duration(seconds: 4), () => refresh(() => status = ''));
    } catch (e) {
      refresh(() => status = 'تعذر التعرف: $e');
    } finally {
      refresh(() {
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
      if (m.playhead >= m.duration - 0.1) m.seek(0);
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
    refresh();
  }

  // ── المعاينة والصور المصغّرة ──
  final images = <String, ui.Image>{};
  bool _loadingImages = false;
  Future<void> _loadImages() async {
    if (_loadingImages) return;
    _loadingImages = true;
    for (final b in [...bgs]) {
      if (!images.containsKey(b.preview)) images[b.preview] = await decodeImageFromList(await File(b.preview).readAsBytes());
    }
    _loadingImages = false;
    if (mounted) refresh();
  }

  List<Bg> get activeBgs => look.manyBgs ? bgs : bgs.take(1).toList();

  Composer composer() {
    final q = quran!;
    final (name, bas) = q.header(surah);
    final list = m.valid;
    return Composer(m, look, activeBgs, images, textsForFont([for (final g in list) g.text], q.nextWord(surah, to)),
        look.showName ? name : null, look.showBasmala ? bas : null);
  }

  final thumbs = <int, ui.Image>{};
  final _thumbQueue = <int>{};
  String _thumbSig = '';
  Composer? _comp;
  bool _thumbBusy = false;

  String _signature() => [
        for (final g in m.valid) '${g.text}${g.start}${g.end}',
        m.cuts, surah, look.fontSize, look.textY, look.width, look.lineGap, look.color, look.shadow, look.align,
        look.headerMode, look.showName, look.showBasmala, look.headerSize, look.headerY, look.headerColor, look.dim,
        look.blur, look.manyBgs, look.bgChange, look.bgEvery, look.transition, [for (final b in bgs) b.path], images.length,
      ].join('|');

  ui.Image? thumbAt(double t) {
    final key = (t * 2).round();
    final img = thumbs[key];
    if (img == null && _comp != null) {
      _thumbQueue.add(key);
      _drainThumbs();
    }
    return img;
  }

  Future<void> _drainThumbs() async {
    if (_thumbBusy) return;
    _thumbBusy = true;
    while (_thumbQueue.isNotEmpty && mounted) {
      final key = _thumbQueue.first;
      _thumbQueue.remove(key);
      final comp = _comp, sig = _thumbSig;
      if (comp == null || thumbs.containsKey(key)) continue;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(72 / vw);
      comp.paint(c, key / 2);
      final img = await rec.endRecording().toImage(72, 128);
      if (sig != _thumbSig) {
        img.dispose();
        continue;
      }
      thumbs[key] = img;
      if (_thumbQueue.isEmpty || thumbs.length % 6 == 0) m.changed();
      await Future<void>.delayed(Duration.zero);
    }
    _thumbBusy = false;
  }

  void _openFullscreen() {
    if (m.valid.isEmpty || audioPath == null) return;
    player.pause();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PreviewPage(audio: audioPath!, composer: composer())));
  }

  // ── التصدير ──
  Future<void> export() async {
    final q = quran, a = audioPath;
    if (q == null || a == null || busy) return;
    final list = m.valid;
    if (list.isEmpty) return;
    player.pause();
    final (name, bas) = q.header(surah);
    final prog = ValueNotifier(0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('جارٍ التصدير'),
          content: ValueListenableBuilder(
            valueListenable: prog,
            builder: (_, p, _) => Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(value: p),
              const SizedBox(height: 12),
              Text('${(p * 100).round()}٪'),
            ]),
          ),
        ),
      ),
    );
    busy = true;
    try {
      final end = (list.last.end + 0.8).clamp(0.0, m.duration);
      final out = await renderVideo(
        audio: a,
        segs: list,
        texts: textsForFont([for (final g in list) g.text], q.nextWord(surah, to)),
        bgs: activeBgs,
        look: look,
        headerName: look.showName ? name : null,
        headerBasmala: look.showBasmala ? bas : null,
        kept: keptRanges(0, end, m.cuts),
        onProgress: (p) => prog.value = p,
      );
      await Gal.putVideo(out, album: 'تلاوة');
      if (mounted) Navigator.of(context).pop();
      _toast('حُفظ الفيديو في معرض الصور (ألبوم «تلاوة»)');
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _toast('تعذر التصدير: $e');
    } finally {
      busy = false;
    }
  }

  void _toast(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // ── الواجهة ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: audioPath == null ? _welcome() : _editor()),
    );
  }

  Widget _welcome() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تلاوة', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('ارفع تلاوة، فيتعرف التطبيق على الآيات ويوقّتها، ثم تحرّر وتصدّر الفيديو.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
              onPressed: busy || quran == null ? null : pickAudio,
              icon: const Icon(Icons.add),
              label: const Text('مشروع جديد: اختر التلاوة'),
            ),
            if (status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text(status)),
          ]),
        ),
      );

  Widget _editor() => Column(children: [
        _topBar(),
        Expanded(child: _previewArea()),
        _controls(),
        Directionality(textDirection: TextDirection.ltr, child: Timeline(m, thumb: thumbAt, onScrub: player.pause)),
        if (m.tapIndex != null)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(48)),
                  onPressed: () => m.tap(m.playhead),
                  child: const Text('المقطع التالي يبدأ الآن ⏭', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: toggleTap, child: const Text('إنهاء')),
            ]),
          ),
        _bottomBar(),
      ]);

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.close), tooltip: 'مشروع جديد', onPressed: busy ? null : pickAudio),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(10)),
            child: Text(quran == null ? 'تلاوة' : 'سورة ${quran!.names[surah - 1]} · 1080p', style: const TextStyle(fontSize: 14)),
          ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 22)),
            onPressed: busy ? null : export,
            child: const Text('تصدير', style: TextStyle(fontSize: 16)),
          ),
        ]),
      );

  Widget _previewArea() => ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          if (quran == null) return const SizedBox();
          if (activeBgs.any((b) => !images.containsKey(b.preview))) _loadImages();
          final comp = composer(), sig = _signature();
          _comp = comp;
          if (sig != _thumbSig) {
            _thumbSig = sig;
            for (final i in thumbs.values) {
              i.dispose();
            }
            thumbs.clear();
            _thumbQueue.clear();
          }
          return Container(
            color: const Color(0xFF0B0B0B),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Stack(alignment: Alignment.center, children: [
              GestureDetector(onTap: togglePlay, child: FrameView(comp, m.playhead)),
              if (status.isNotEmpty || progress != null)
                Positioned(
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(status, style: const TextStyle(fontSize: 13)),
                      if (progress != null) SizedBox(width: 160, child: LinearProgressIndicator(value: progress)),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );

  Widget _controls() => ListenableBuilder(
        listenable: m,
        builder: (context, _) => Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              IconButton(onPressed: m.canUndo ? m.undo : null, icon: const Icon(Icons.undo), tooltip: 'تراجع'),
              IconButton(onPressed: m.canRedo ? m.redo : null, icon: const Icon(Icons.redo), tooltip: 'إعادة'),
              Text('${fmtTime(m.toDisp(m.playhead))} / ${fmtTime(m.dispDuration)}', style: const TextStyle(fontSize: 13)),
              const Spacer(),
              IconButton(iconSize: 34, onPressed: togglePlay, icon: Icon(player.playing ? Icons.pause : Icons.play_arrow)),
              const Spacer(),
              IconButton(onPressed: _openFullscreen, icon: const Icon(Icons.fullscreen), tooltip: 'ملء الشاشة'),
            ]),
          ),
        ),
      );

  // ── شريط الأدوات السفلي المنزلق: يتغير حسب المحدد (مقطع نص، قطعة صوت، أو لا شيء) ──
  Widget _tool(IconData icon, String label, VoidCallback? on) => InkWell(
        onTap: on,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: on == null ? 0.4 : 1,
          child: SizedBox(
            width: 76,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 26),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12, height: 1.2)),
            ]),
          ),
        ),
      );

  Widget _bottomBar() => ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          final List<Widget> items;
          Widget? back;
          if (m.sel != null) {
            back = IconButton(icon: const Icon(Icons.keyboard_double_arrow_down), onPressed: () => m.select(null));
            items = [
              _tool(Icons.edit_note, 'تحرير النص', _editTextSheet),
              _tool(Icons.content_cut, 'تقسيم', _splitSheet),
              _tool(Icons.start, 'البداية هنا', m.setStartHere),
              _tool(Icons.keyboard_tab, 'النهاية هنا', m.setEndHere),
              _tool(Icons.copy, 'تكرار', m.duplicate),
              _tool(Icons.call_merge, 'دمج مع التالي', m.mergeNext),
              _tool(Icons.delete_outline, 'حذف', m.deleteSeg),
            ];
          } else if (m.audioSel != null) {
            back = IconButton(icon: const Icon(Icons.keyboard_double_arrow_down), onPressed: () => m.select(null));
            items = [
              _tool(Icons.content_cut, 'تقسيم', m.splitAudio),
              _tool(Icons.delete_outline, 'حذف', m.deleteAudio),
              _tool(Icons.restore, 'استرجاع المحذوف', m.cuts.isEmpty ? null : m.restoreAudio),
            ];
          } else {
            items = [
              _tool(Icons.auto_fix_high, 'تعرّف تلقائي', busy ? null : autoSync),
              _tool(Icons.menu_book, 'الآيات', _ayatSheet),
              _tool(Icons.graphic_eq, 'الصوت', () => m.selectAudioAt(m.playhead)),
              _tool(Icons.wallpaper, 'الخلفية', () => _sheet(_bgPanel)),
              _tool(Icons.text_fields, 'النص', () => _sheet(_textPanel)),
              _tool(Icons.title, 'الترويسة', () => _sheet(_headerPanel)),
              _tool(Icons.touch_app, 'مزامنة بالنقر', toggleTap),
            ];
          }
          return Container(
            height: 78,
            color: const Color(0xFF181818),
            child: Row(children: [
              ?back,
              Expanded(child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6), children: items)),
            ]),
          );
        },
      );

  // ── اللوحات السفلية (المعاينة ظاهرة فوقها) ──
  void _sheet(Widget Function() panel) => showModalBottomSheet(
        context: context,
        barrierColor: Colors.black26,
        backgroundColor: const Color(0xFF1C1C1C),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.42),
        builder: (_) => ValueListenableBuilder(valueListenable: ui0, builder: (_, _, _) => panel()),
      );

  Widget _pad(List<Widget> c) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: c);
  Widget _wrap(List<Widget> c) => Wrap(spacing: 8, runSpacing: 8, children: c);

  Widget _slider(String label, double v, double lo, double hi, void Function(double) on, {int div = 20}) => Row(children: [
        SizedBox(width: 104, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(child: Slider(value: v.clamp(lo, hi), min: lo, max: hi, divisions: div, onChanged: (x) => refresh(() => on(x)))),
      ]);

  void _editTextSheet() {
    final g = m.sel;
    if (g == null) return;
    final ctl = TextEditingController(text: g.text);
    m.checkpoint();
    _sheet(() => _pad([
          const Text('نص المقطع'),
          TextField(controller: ctl, maxLines: 3, autofocus: true, style: const TextStyle(fontSize: 18), onChanged: (v) {
            g.text = v.trim();
            m.changed();
          }),
        ]));
  }

  void _splitSheet() {
    final g = m.sel;
    if (g == null) return;
    _sheet(() => _pad([
          const Text('اختر الكلمة التي يبدأ بها الجزء الثاني (يبدأ من موضع المؤشر):'),
          const SizedBox(height: 10),
          _wrap([
            for (final (i, w) in splitWords(g.text).indexed)
              if (i > 0)
                ActionChip(
                  label: Text(w.replaceAll(marks, ''), style: const TextStyle(fontSize: 16)),
                  onPressed: () {
                    m.splitAt(i);
                    Navigator.of(context).pop();
                  },
                ),
          ]),
        ]));
  }

  void _ayatSheet() {
    final q = quran;
    if (q == null) return;
    final addCtl = TextEditingController(text: '1');
    _sheet(() {
      final n = q.ayat[surah - 1].length;
      return _pad([
        DropdownButton<int>(
          isExpanded: true,
          value: surah,
          items: [for (var i = 1; i <= 114; i++) DropdownMenuItem(value: i, child: Text('$i. ${q.names[i - 1]}'))],
          onChanged: (v) => refresh(() {
            surah = v!;
            from = 1;
            to = q.ayat[v - 1].length.clamp(1, 5);
          }),
        ),
        Row(children: [
          Expanded(child: _numField('من آية', from, 1, n, (v) => refresh(() => from = v))),
          const SizedBox(width: 8),
          Expanded(child: _numField('إلى آية', to, from, n, (v) => refresh(() => to = v))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _distribute, child: const Text('توزيع تقريبي')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: addCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'إضافة آية عند المؤشر (رقمها)'))),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              final a = int.tryParse(addCtl.text);
              if (a != null && a >= 1 && a <= n) m.addAt(q.ayahText(surah, a));
            },
            child: const Text('+ أضف'),
          ),
        ]),
      ]);
    });
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

  Widget _bgPanel() => _pad([
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('خلفية واحدة')), ButtonSegment(value: true, label: Text('عدة خلفيات تتبدّل'))],
          selected: {look.manyBgs},
          onSelectionChanged: (s) => refresh(() {
            look.manyBgs = s.first;
            if (!look.manyBgs && bgs.length > 1) bgs.removeRange(1, bgs.length);
          }),
        ),
        const SizedBox(height: 10),
        _wrap([
          for (var i = 0; i < presets.length; i++)
            FilterChip(
              label: Text(presets[i]),
              selected: bgs.any((b) => b.name == presets[i]),
              onSelected: (_) async {
                final b = await _presetBg(i);
                refresh(() {
                  final at = bgs.indexWhere((x) => x.name == b.name);
                  if (!look.manyBgs) {
                    bgs
                      ..clear()
                      ..add(b);
                  } else if (at >= 0) {
                    if (bgs.length > 1) bgs.removeAt(at);
                  } else {
                    bgs.add(b);
                  }
                });
              },
            ),
          ActionChip(
            avatar: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('من المعرض'),
            onPressed: () async {
              final files = look.manyBgs ? await FilePicker.pickFiles(type: FileType.media) : [?(await FilePicker.pickFile(type: FileType.media))];
              final added = <Bg>[];
              for (final f in files.where((f) => f.path != null)) {
                final v = isVideo(f.path!);
                added.add(Bg(f.path!, f.name, video: v, thumb: v ? await videoThumb(f.path!) : null));
              }
              refresh(() {
                if (!look.manyBgs) bgs.clear();
                bgs.addAll(look.manyBgs ? added : added.take(1));
              });
            },
          ),
        ]),
        if (look.manyBgs && bgs.length > 1) ...[
          const SizedBox(height: 6),
          Text('المختارة: ${bgs.map((b) => b.name).join('، ')}', style: const TextStyle(fontSize: 12)),
          DropdownButton<String>(value: look.bgChange, items: const [
            DropdownMenuItem(value: 'time', child: Text('تتبدّل كل عدد من الثواني')),
            DropdownMenuItem(value: 'segment', child: Text('تتبدّل مع كل مقطع')),
          ], onChanged: (v) => refresh(() => look.bgChange = v!)),
          if (look.bgChange == 'time') _slider('كل ${look.bgEvery.round()} ث', look.bgEvery, 3, 30, (x) => look.bgEvery = x, div: 27),
          DropdownButton<String>(value: look.transition, items: const [
            DropdownMenuItem(value: 'fade', child: Text('انتقال: تلاشٍ')),
            DropdownMenuItem(value: 'fadeblack', child: Text('انتقال: عبر الأسود')),
            DropdownMenuItem(value: 'slideright', child: Text('انتقال: انزلاق')),
            DropdownMenuItem(value: 'circleopen', child: Text('انتقال: دائرة')),
            DropdownMenuItem(value: 'none', child: Text('بلا انتقال')),
          ], onChanged: (v) => refresh(() => look.transition = v!)),
        ],
        _slider('تعتيم', look.dim, 0, 0.8, (x) => look.dim = x, div: 16),
        _slider('تضبيب', look.blur, 0, 20, (x) => look.blur = x),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('تقريب بطيء للصور (يبطئ التصدير)'), value: look.zoom,
            onChanged: (v) => refresh(() => look.zoom = v)),
      ]);

  Widget _textPanel() => _pad([
        _slider('حجم الخط', look.fontSize, 30, 120, (x) => look.fontSize = x, div: 90),
        _slider('الموضع', look.textY, 0.15, 0.9, (x) => look.textY = x, div: 75),
        _slider('عرض السطر', look.width, 0.5, 0.95, (x) => look.width = x, div: 45),
        _slider('تباعد الأسطر', look.lineGap, 1.3, 2.6, (x) => look.lineGap = x, div: 13),
        _slider('الظل', look.shadow, 0, 1, (x) => look.shadow = x),
        _slider('الظهور والاختفاء', look.fade, 0, 1, (x) => look.fade = x),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'right', label: Text('يمين')), ButtonSegment(value: 'center', label: Text('توسيط')), ButtonSegment(value: 'left', label: Text('يسار'))],
          selected: {look.align},
          onSelectionChanged: (s) => refresh(() => look.align = s.first),
        ),
        const SizedBox(height: 8),
        Row(children: [const Text('اللون  '), for (final c in swatches) _swatch(c, look.color, (x) => look.color = x)]),
      ]);

  Widget _headerPanel() => _pad([
        DropdownButton<String>(isExpanded: true, value: look.headerMode, items: const [
          DropdownMenuItem(value: 'mushaf', child: Text('إطار المصحف وبسملة مزخرفة')),
          DropdownMenuItem(value: 'basmala', child: Text('بسملة مزخرفة')),
          DropdownMenuItem(value: 'plain', child: Text('نص عادي')),
        ], onChanged: (v) => refresh(() => look.headerMode = v!)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('اسم السورة'), value: look.showName, onChanged: (v) => refresh(() => look.showName = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('البسملة'), value: look.showBasmala, onChanged: (v) => refresh(() => look.showBasmala = v)),
        _slider('الحجم', look.headerSize, 24, 90, (x) => look.headerSize = x, div: 66),
        _slider('الموضع', look.headerY, 0.03, 0.4, (x) => look.headerY = x, div: 37),
        Row(children: [const Text('اللون  '), for (final c in swatches) _swatch(c, look.headerColor, (x) => look.headerColor = x)]),
      ]);

  Widget _swatch(Color c, Color current, void Function(Color) on) => GestureDetector(
        onTap: () => refresh(() => on(c)),
        child: Container(
          margin: const EdgeInsets.all(4),
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: current == c ? accent : Colors.grey, width: current == c ? 3 : 1)),
        ),
      );
}
