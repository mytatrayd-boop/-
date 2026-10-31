import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'share_card.dart';
import 'share_card_data.dart';

const logoMarkAsset = 'assets/logo-mark.png';

/// يفكّ صورة الفحص بعرض أقصاه [maxWidth] (الصور الكبيرة لا تُحمَّل بدقتها الكاملة). null إن فُقد الملف أو تلف.
Future<ui.Image?> loadScanPhoto(String path, {int maxWidth = 1200}) async {
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return await _decode(await file.readAsBytes(), maxWidth: maxWidth);
  } catch (_) {
    return null;
  }
}

Future<ui.Image> loadLogoMark(AssetBundle bundle) async {
  final data = await bundle.load(logoMarkAsset);
  return _decode(data.buffer.asUint8List(), maxWidth: 800);
}

Future<ui.Image> _decode(Uint8List bytes, {required int maxWidth}) async {
  final probe = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(probe);
    final codec = await descriptor.instantiateCodec(
        targetWidth: descriptor.width > maxWidth ? maxWidth : null);
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    return frame.image;
  } finally {
    probe.dispose();
  }
}

/// جلسة رسم خارج الشاشة: [start] يُدرج البطاقة في طبقة Overlay خارج المساحة المرئية،
/// وبعد إطار واحد يلتقطها [capture] PNG بمقاس 1080×1350 بالضبط، ثم [dispose] تزيل الطبقة.
class ShareCardSession {
  ShareCardSession._(this._entry, this._key);

  final OverlayEntry _entry;
  final GlobalKey _key;

  factory ShareCardSession.start(BuildContext context, ShareCardData data) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -(ShareCard.width + 400),
        top: -(ShareCard.height + 400),
        width: ShareCard.width,
        height: ShareCard.height,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(ShareCard.width, ShareCard.height),
                devicePixelRatio: 1,
                textScaler: TextScaler.noScaling,
              ),
              child: RepaintBoundary(key: key, child: ShareCard(data: data)),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    return ShareCardSession._(entry, key);
  }

  Future<Uint8List> capture() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  void dispose() => _entry.remove();
}

/// يرسم البطاقة خارج الشاشة ويعيد PNG.
Future<Uint8List> renderShareCardPng(BuildContext context, ShareCardData data) async {
  final session = ShareCardSession.start(context, data);
  try {
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    return await session.capture();
  } finally {
    session.dispose();
  }
}
