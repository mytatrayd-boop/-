import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/weather_symbol.dart';
import '../../theme/app_theme.dart';
import '../common/glass.dart';
import '../common/weather_icon.dart';

/// فقاعة شرح رمز الجو (DESIGN R2.6، SPEC الميزة 16): اسم الرمز وسطر شرحه
/// والفترة التي يتبعها. لا تفتح صفحة؛ فقاعة واحدة فقط.
///
/// تُفتح فوق الشاشة كمسار منبثق شفاف: أول لمس خارجها (ضغطة أو بداية سحب
/// أو تدوير) يغلقها فوراً، والضغطة القصيرة تُمرَّر نقطتها إلى [onOutsideTap]
/// لتفتح فقاعة رمز آخر إن وقعت عليه؛ والرجوع يغلقها. فقاعة واحدة فقط. عند
/// تكبير الخط ≥ 1.5× تصبح ورقة سفلية صغيرة بالمحتوى نفسه.
Future<void> showSymbolBubble(
  BuildContext context, {
  required Rect anchor,
  required WeatherSymbol symbol,
  required String period,
  bool preferBelow = true,
  ValueChanged<Offset>? onOutsideTap,
}) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  final content = SymbolBubbleContent(symbol: symbol, period: period);
  if (scale >= 1.5) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        child: content,
      ),
    );
  }
  return Navigator.of(context, rootNavigator: true).push(
    _BubbleRoute(
      anchor: anchor,
      preferBelow: preferBelow,
      content: content,
      label: weatherSymbolLabel(AppLocalizations.of(context), symbol),
      closeLabel: AppLocalizations.of(context).commonClose,
      onOutsideTap: onOutsideTap,
    ),
  );
}

/// محتوى الفقاعة (DESIGN R2.6): الرمز 24 بلونه الدلالي + اسمه (17)، سطر
/// الشرح (15)، وسطر الفترة (13، `ink-soft`). يُعلَن لقارئ الشاشة عند فتحه.
class SymbolBubbleContent extends StatelessWidget {
  const SymbolBubbleContent({
    super.key,
    required this.symbol,
    required this.period,
  });

  static const contentKey = Key('symbolBubble');

  final WeatherSymbol symbol;
  final String period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final name = weatherSymbolLabel(l10n, symbol);
    final desc = l10n.weatherSymbolDesc(symbol.code);
    return Semantics(
      key: contentKey,
      container: true,
      liveRegion: true,
      label: '$name. $desc $period',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WeatherIcon(
                  symbol,
                  size: 24,
                  color: colors.weatherTone(symbol.code),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(desc, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(period, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _BubbleRoute extends PopupRoute<void> {
  _BubbleRoute({
    required this.anchor,
    required this.preferBelow,
    required this.content,
    required this.label,
    required this.closeLabel,
    this.onOutsideTap,
  });

  final Rect anchor;
  final bool preferBelow;
  final Widget content;
  final String label;
  final String closeLabel;
  final ValueChanged<Offset>? onOutsideTap;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    // عرض 220–280dp، ولا يتجاوز عرض الشاشة − 32.
    final arrowUp = _ArrowSide();
    final bubbleWidth = math.max(0.0, math.min(280.0, width - 32));
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            label: closeLabel,
            button: true,
            onTap: () => Navigator.of(context).pop(),
            child: _OutsideCloser(
              onClose: () => Navigator.of(context).pop(),
              onTap: onOutsideTap,
            ),
          ),
        ),
        CustomMultiChildLayout(
          delegate: _BubbleLayout(
            anchor: anchor,
            preferBelow: preferBelow,
            width: bubbleWidth,
            padding: media.padding,
            side: arrowUp,
          ),
          children: [
            LayoutId(
              id: _BubblePart.arrow,
              child: CustomPaint(
                painter: _ArrowPainter(
                  DururColors.of(context).glassStroke,
                  arrowUp,
                ),
              ),
            ),
            LayoutId(
              id: _BubblePart.body,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: label,
                child: Material(
                  type: MaterialType.transparency,
                  child: GlassSurface(
                    radius: 16,
                    fill: const Color(0xF20E2036),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.of(context).disableAnimations
      ? child
      : FadeTransition(opacity: animation, child: child);
}

/// يغلق الفقاعة عند أول لمس خارجها (قبل أن يصير سحباً أو تدويراً)، ثم إن
/// رُفع الإصبع دون حركة تُعدّ ضغطة وتُمرَّر نقطتها.
class _OutsideCloser extends StatefulWidget {
  const _OutsideCloser({required this.onClose, this.onTap});

  final VoidCallback onClose;
  final ValueChanged<Offset>? onTap;

  @override
  State<_OutsideCloser> createState() => _OutsideCloserState();
}

class _OutsideCloserState extends State<_OutsideCloser> {
  Offset? _down;
  bool _closed = false;

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _down = e.position;
        _close();
      },
      onPointerUp: (e) {
        final down = _down;
        _down = null;
        if (down != null && (e.position - down).distance < kTouchSlop) {
          onTap?.call(down);
        }
      },
      onPointerCancel: (_) => _down = null,
    );
  }
}

enum _BubblePart { arrow, body }

/// تحت الرمز إن اتسع (أو فوقه)، مزاحة أفقياً لتبقى داخل الشاشة بهامش 16،
/// وسهم 10dp يشير للرمز.
class _BubbleLayout extends MultiChildLayoutDelegate {
  _BubbleLayout({
    required this.anchor,
    required this.preferBelow,
    required this.width,
    required this.padding,
    required this.side,
  });

  final Rect anchor;
  final bool preferBelow;
  final double width;
  final EdgeInsets padding;

  /// اتجاه السهم يُقرَّر هنا ويُقرأ عند الرسم (بعد التخطيط في الإطار نفسه).
  final _ArrowSide side;

  static const _arrow = 10.0;
  static const _margin = 16.0;

  @override
  void performLayout(Size size) {
    final body = layoutChild(
      _BubblePart.body,
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: size.height - padding.vertical - 2 * _margin,
      ),
    );
    final top = padding.top + _margin;
    final bottom = size.height - padding.bottom - _margin;
    final belowY = anchor.bottom + _arrow;
    final aboveY = anchor.top - _arrow - body.height;
    final fitsBelow = belowY + body.height <= bottom;
    final fitsAbove = aboveY >= top;
    final below = preferBelow ? (fitsBelow || !fitsAbove) : !fitsAbove;
    final y = (below ? belowY : aboveY)
        .clamp(top, math.max(top, bottom - body.height))
        .toDouble();
    final x = (anchor.center.dx - width / 2)
        .clamp(_margin, math.max(_margin, size.width - _margin - width))
        .toDouble();
    positionChild(_BubblePart.body, Offset(x, y));

    layoutChild(
      _BubblePart.arrow,
      BoxConstraints.tight(const Size(2 * _arrow, _arrow)),
    );
    final ax = (anchor.center.dx - _arrow)
        .clamp(x + 12, math.max(x + 12, x + width - 12 - 2 * _arrow))
        .toDouble();
    positionChild(
      _BubblePart.arrow,
      Offset(ax, below ? y - _arrow : y + body.height),
    );
    side.up = below;
  }

  @override
  bool shouldRelayout(_BubbleLayout old) =>
      old.anchor != anchor ||
      old.preferBelow != preferBelow ||
      old.width != width ||
      old.padding != padding;
}

class _ArrowSide {
  bool up = true;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color, this.side);

  final Color color;
  final _ArrowSide side;

  @override
  void paint(Canvas canvas, Size size) {
    final path = side.up
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height)
            ..close())
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0)
            ..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color || old.side != side;
}
