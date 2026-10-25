import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// بيانات البطاقة بعد الترجمة؛ لا إحداثيات ولا بريد (SPEC F8 معيار 4).
class ShareCardData {
  const ShareCardData({
    required this.photo,
    required this.logo,
    required this.score,
    required this.scoreText,
    required this.scoreOutOf,
    required this.title,
    required this.typeLabel,
    required this.appName,
    required this.brand,
    required this.textDirection,
    this.rating,
    this.shopName,
    this.note,
  });

  final ui.Image photo;
  final ui.Image? logo;
  final double score;
  final String scoreText;
  final String scoreOutOf;
  final String title;
  final String typeLabel;
  final String appName;
  final String brand;
  final TextDirection textDirection;
  final int? rating;
  final String? shopName;
  final String? note;
}

/// بطاقة المشاركة (DESIGN §4): مقاس منطقي 360×450 تُصوَّر بـ pixelRatio 3
/// إلى 1080×1350. القيم بالبكسل النهائي وتُقسم على 3. الثيم الفاتح دائماً.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  static const size = Size(360, 450);
  static const pixelRatio = 3.0;

  static const _bg = Color(0xFFFAF6F0);
  static const _frame = Color(0xFFE3D6C6);
  static const _ink = Color(0xFF2B1D14);
  static const _muted = Color(0xFF6B5A4E);
  static const _caramel = Color(0xFFB87628);
  static const _track = Color(0xFFEAD9C6);
  static const _starEmpty = Color(0xFFD9C9B6);
  static const _brown = Color(0xFF6F4E37);

  final ShareCardData data;

  static double _px(double v) => v / pixelRatio;

  TextStyle _style(double px, FontWeight weight, Color color) => TextStyle(
        fontFamily: 'Tajawal',
        fontSize: _px(px),
        fontWeight: weight,
        color: color,
        height: 1.25,
        decoration: TextDecoration.none,
      );

  @override
  Widget build(BuildContext context) {
    const ring = 260.0;
    return Directionality(
      textDirection: data.textDirection,
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: _bg),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(_px(36)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: _frame, width: _px(3)),
                      borderRadius: BorderRadius.circular(_px(48)),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: _px(72),
                top: _px(72),
                width: _px(936),
                height: _px(688),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_px(40)),
                  child: RawImage(image: data.photo, fit: BoxFit.cover),
                ),
              ),
              PositionedDirectional(
                end: _px(236 - ring / 2),
                top: _px(760 - ring / 2),
                width: _px(ring),
                height: _px(ring),
                child: _ScoreBadge(data: data, style: _style),
              ),
              PositionedDirectional(
                start: _px(72),
                end: _px(400),
                top: _px(800),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(data.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: _style(44, FontWeight.w700, _ink)),
                    ),
                    SizedBox(width: _px(16)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: _px(20), vertical: _px(6)),
                      decoration: BoxDecoration(color: _track, borderRadius: BorderRadius.circular(_px(24))),
                      child: Text(data.typeLabel, style: _style(30, FontWeight.w600, _ink)),
                    ),
                  ],
                ),
              ),
              if (data.rating != null)
                PositionedDirectional(
                  start: _px(72),
                  top: _px(880),
                  child: Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(Icons.star_rounded, size: _px(56), color: i <= data.rating! ? _caramel : _starEmpty),
                    ],
                  ),
                ),
              if (data.shopName != null)
                PositionedDirectional(
                  start: _px(72),
                  end: _px(72),
                  top: _px(960),
                  child: Row(
                    children: [
                      Icon(Icons.place_outlined, size: _px(36), color: _ink),
                      SizedBox(width: _px(8)),
                      Expanded(
                        child: Text(data.shopName!,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: _style(36, FontWeight.w600, _ink)),
                      ),
                    ],
                  ),
                ),
              if (data.note != null)
                PositionedDirectional(
                  start: _px(72),
                  end: _px(72),
                  top: _px(1030),
                  height: _px(140),
                  child: Text('«${data.note}»',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: _style(32, FontWeight.w400, _muted)),
                ),
              PositionedDirectional(
                start: _px(72),
                end: _px(72),
                top: _px(1210),
                height: _px(68),
                child: Column(
                  children: [
                    Container(height: _px(2), color: _frame),
                    const Spacer(),
                    Row(
                      children: [
                        if (data.logo != null)
                          SizedBox.square(dimension: _px(64), child: RawImage(image: data.logo)),
                        SizedBox(width: _px(16)),
                        Text(data.appName, style: _style(32, FontWeight.w700, _brown)),
                        const Spacer(),
                        Text(data.brand, style: _style(28, FontWeight.w500, _muted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.data, required this.style});

  final ShareCardData data;
  final TextStyle Function(double, FontWeight, Color) style;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RingPainter(
          fraction: (data.score / 10).clamp(0, 1).toDouble(),
          rtl: data.textDirection == TextDirection.rtl,
          stroke: 20 / ShareCard.pixelRatio,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            textDirection: TextDirection.ltr,
            children: [
              Text(data.scoreText, style: style(96, FontWeight.w700, ShareCard._ink)),
              Text(data.scoreOutOf, style: style(36, FontWeight.w400, ShareCard._muted)),
            ],
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.rtl, required this.stroke});

  final double fraction;
  final bool rtl;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFFFFF));
    final rect = Rect.fromCircle(center: center, radius: radius - stroke);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, line..color = ShareCard._track);
    // تبدأ من الأعلى وتتجه مع اتجاه اللغة.
    final sweep = 2 * math.pi * fraction * (rtl ? -1 : 1);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, line..color = ShareCard._caramel);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.rtl != rtl || old.stroke != stroke;
}
