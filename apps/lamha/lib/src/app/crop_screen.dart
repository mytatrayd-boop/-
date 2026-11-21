import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../engine/wallpaper_crop.dart';

/// شاشة «ضبط لقطة الخلفية»: اللقطة كاملة وعليها إطار الودجت في موضعه المقدّر من مقاس الجهاز
/// (wallpaper_crop.dart). المستخدم يختار المقاس والموضع، ويسحب الإطار ليضبطه، ثم يحفظ القطعة.
/// تعيد PNG المقصوص، أو null عند الإلغاء.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.bytes});

  final Uint8List bytes;

  static const routeName = '/crop';

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _image;
  var _size = WidgetSize.large;
  var _slot = WidgetSlot.top;
  CropRect? _rect;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _image = frame.image;
      _place();
    });
  }

  void _place() {
    final img = _image;
    if (img == null) return;
    if (!slotsFor(_size).contains(_slot)) _slot = WidgetSlot.top;
    _rect = cropRect(img.width, img.height, _size, _slot);
  }

  Future<void> _save() async {
    final img = _image;
    final r = _rect;
    if (img == null || r == null) return;
    setState(() => _saving = true);
    final png = await cropToPng(img, r);
    if (mounted) Navigator.of(context).pop(png);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final img = _image;
    final r = _rect;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.cropTitle),
        actions: [
          TextButton(
            key: const Key('crop-save'),
            onPressed: img == null || _saving ? null : _save,
            child: Text(l.cropSave),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l.cropHint, textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<WidgetSize>(
              key: const Key('crop-size'),
              showSelectedIcon: false,
              segments: [
                for (final s in WidgetSize.values)
                  ButtonSegment(value: s, label: Text(l.cropSizeName(s.name), key: Key('crop-size-${s.name}'))),
              ],
              selected: {_size},
              onSelectionChanged: (v) => setState(() {
                _size = v.first;
                _place();
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<WidgetSlot>(
              key: const Key('crop-slot'),
              showSelectedIcon: false,
              segments: [
                for (final s in slotsFor(_size))
                  ButtonSegment(value: s, label: Text(l.cropSlotName(s.name), key: Key('crop-slot-${s.name}'))),
              ],
              selected: {_slot},
              onSelectionChanged: (v) => setState(() {
                _slot = v.first;
                _place();
              }),
            ),
          ),
          Expanded(
            child: img == null || r == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(builder: (context, box) {
                      // اللقطة بأكبر مقاس يتسع، والإطار بمقياسها نفسه.
                      final k = [box.maxWidth / img.width, box.maxHeight / img.height].reduce((a, b) => a < b ? a : b);
                      final w = img.width * k;
                      final h = img.height * k;
                      return Center(
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: Stack(
                            children: [
                              Positioned.fill(child: RawImage(image: img, fit: BoxFit.fill)),
                              Positioned(
                                left: r.left * k,
                                top: r.top * k,
                                width: r.width * k,
                                height: r.height * k,
                                child: GestureDetector(
                                  key: const Key('crop-frame'),
                                  onPanUpdate: (d) => setState(() {
                                    _rect = clampRect(
                                      (
                                        left: r.left + d.delta.dx / k,
                                        top: r.top + d.delta.dy / k,
                                        width: r.width,
                                        height: r.height,
                                      ),
                                      img.width,
                                      img.height,
                                    );
                                  }),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}

/// القطعة [r] من [img] صورة PNG بمقاسها الأصلي.
Future<Uint8List> cropToPng(ui.Image img, CropRect r) async {
  final w = r.width.round();
  final h = r.height.round();
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    img,
    Rect.fromLTWH(r.left, r.top, r.width, r.height),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final out = await recorder.endRecording().toImage(w, h);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
