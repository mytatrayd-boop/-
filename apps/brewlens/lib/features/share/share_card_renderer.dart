import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../widgets/app_logo.dart';
import 'share_card.dart';

/// يفك بايتات صورة إلى ui.Image (مع تصغير اختياري للعرض).
Future<ui.Image> decodeImage(Uint8List bytes, {int? targetWidth}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// الشعار من الأصول؛ null إن تعذّر (البطاقة تبقى صالحة بدونه).
Future<ui.Image?> loadLogo({AssetBundle? bundle}) async {
  try {
    final data = await (bundle ?? rootBundle).load(AppLogo.asset);
    return await decodeImage(data.buffer.asUint8List(), targetWidth: 64);
  } on Object {
    return null;
  }
}

/// يرسم ويدجت خارج الشاشة ويعيده PNG بمقاس [size] × [pixelRatio].
Future<Uint8List> renderWidgetToPng(
  Widget widget, {
  required ui.FlutterView view,
  required Size size,
  double pixelRatio = 1,
}) async {
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size),
    ),
    child: RenderPositionedBox(child: boundary),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final focus = FocusManager();
  final buildOwner = BuildOwner(focusManager: focus);
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(data: MediaQueryData(size: size), child: widget),
  ).attachToRenderTree(buildOwner);
  try {
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('png encode failed');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
        .attachToRenderTree(buildOwner, root);
    buildOwner.finalizeTree();
    focus.dispose();
  }
}

/// بطاقة المشاركة PNG بمقاس 1080×1350.
Future<Uint8List> renderShareCard(ShareCardData data, {required ui.FlutterView view}) =>
    renderWidgetToPng(
      ShareCard(data: data),
      view: view,
      size: ShareCard.size,
      pixelRatio: ShareCard.pixelRatio,
    );
