import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../common/glass.dart';

/// إطار التبويبات (DESIGN R2.9، R3.1-19): كبسولة زجاجية بأربعة تبويبات من اليمين:
/// الدائرة، الرموز، التراث، الإعدادات. كل تبويب يحفظ حالته
/// ([StatefulNavigationShell])، والصفحات الكاملة والأوراق السفلية تُفتح فوق
/// الشريط فيختفي تحتها.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  static const tabBarKey = Key('appTabBar');
  static Key tabKey(int index) => Key('appTab$index');

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDeep,
      body: shell,
      bottomNavigationBar: _GlassTabBar(
        index: shell.currentIndex,
        onSelect: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

/// الكبسولة (R3.1-19): زجاجية، عرضها min(العرض − 32، 360) على الهاتف و44%
/// على الجهاز اللوحي، ارتفاعها 56 وزواياها 28، في المنتصف بهامش 12 من
/// الأسفل. تسميات بلا أيقونات (Almarai 15)؛ وعند تكبير الخط ≥ 1.5× أيقونات
/// R2.9 فقط وأسماؤها لقارئ الشاشة.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.tabWheel,
      l10n.tabSymbols,
      l10n.tabHeritage,
      l10n.tabSettings,
    ];
    final showLabels = MediaQuery.textScalerOf(context).scale(1) < 1.5;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final capsule = width >= 600
        ? width * 0.437
        : (width - 32).clamp(0.0, 360.0);
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: 12 + bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            key: AppShell.tabBarKey,
            width: capsule,
            height: 56,
            child: GlassSurface(
              radius: 28,
              fill: const Color(0xE616303C),
              borderColor: const Color(0x668FB3C0),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: Row(
                  children: [
                    for (final (i, label) in labels.indexed)
                      Expanded(
                        child: _Tab(
                          key: AppShell.tabKey(i),
                          label: label,
                          icon: _TabIcon.values[i],
                          selected: i == index,
                          showLabel: showLabels,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final String label;
  final _TabIcon icon;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    // المختار: حبة surface-selected ونص ink بوزن 800؛ غيره ink-soft بوزن 700.
    final textColor = selected ? colors.ink : colors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: selected ? colors.surfaceAlt : null,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 44,
                    maxHeight: 44,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 6,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: showLabel
                          ? MediaQuery.withNoTextScaling(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(
                                  fontFamily: DururFonts.body,
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: textColor,
                                  height: 1.2,
                                ),
                              ),
                            )
                          : CustomPaint(
                              size: const Size.square(24),
                              painter: _TabIconPainter(
                                icon,
                                selected ? colors.primary : colors.inkSoft,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _TabIcon { wheel, symbols, heritage, settings }

/// أيقونات التبويب الخطية من رسمنا (القسم 6): شبكة 24، خط 2.
class _TabIconPainter extends CustomPainter {
  const _TabIconPainter(this.icon, this.color);

  final _TabIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = color;
    const c = Offset(12, 12);
    switch (icon) {
      case _TabIcon.wheel:
        canvas.drawCircle(c, 9.5, p);
        canvas.drawCircle(c, 5.5, p);
        canvas.drawLine(const Offset(12, 2.5), const Offset(12, 8), p);
        canvas.drawCircle(c, 1.2, dot);
      case _TabIcon.symbols:
        canvas.drawCircle(const Offset(7, 7), 2.5, p);
        canvas.drawPath(
          Path()
            ..moveTo(17, 3.5)
            ..cubicTo(15.5, 5.5, 14, 7.1, 14, 8.5)
            ..arcToPoint(
              const Offset(20, 8.5),
              radius: const Radius.circular(3),
              clockwise: false,
            )
            ..cubicTo(20, 7.1, 18.5, 5.5, 17, 3.5),
          p,
        );
        canvas.drawLine(const Offset(3.5, 16), const Offset(10.5, 16), p);
        canvas.drawLine(const Offset(3.5, 20), const Offset(8.5, 20), p);
        canvas.drawPath(
          Path()
            ..moveTo(14, 17.5)
            ..lineTo(20.5, 17.5)
            ..arcToPoint(
              const Offset(20.5, 13.1),
              radius: const Radius.circular(2.2),
              clockwise: false,
            )
            ..arcToPoint(
              const Offset(14.2, 13.7),
              radius: const Radius.circular(3.3),
              clockwise: false,
            )
            ..arcToPoint(
              const Offset(14, 17.5),
              radius: const Radius.circular(2),
              clockwise: false,
            ),
          p,
        );
      case _TabIcon.heritage:
        canvas.drawLine(const Offset(12, 22), const Offset(12, 10), p);
        canvas.drawPath(
          Path()
            ..moveTo(12, 10)
            ..quadraticBezierTo(8, 5, 3, 8)
            ..moveTo(12, 10)
            ..quadraticBezierTo(16, 5, 21, 8)
            ..moveTo(12, 10)
            ..quadraticBezierTo(10, 5, 13, 2.5),
          p,
        );
        canvas.drawLine(const Offset(3, 22), const Offset(21, 22), p);
      case _TabIcon.settings:
        canvas.drawCircle(c, 3, p);
        canvas.drawCircle(c, 7, p);
        for (final (a, b) in const [
          (Offset(12, 2), Offset(12, 5)),
          (Offset(12, 19), Offset(12, 22)),
          (Offset(2, 12), Offset(5, 12)),
          (Offset(19, 12), Offset(22, 12)),
          (Offset(4.9, 4.9), Offset(7, 7)),
          (Offset(17, 17), Offset(19.1, 19.1)),
          (Offset(4.9, 19.1), Offset(7, 17)),
          (Offset(17, 7), Offset(19.1, 4.9)),
        ]) {
          canvas.drawLine(a, b, p);
        }
    }
  }

  @override
  bool shouldRepaint(_TabIconPainter old) =>
      old.icon != icon || old.color != color;
}
