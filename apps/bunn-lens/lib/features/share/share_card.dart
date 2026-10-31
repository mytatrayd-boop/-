import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'fit_text.dart';
import 'share_card_data.dart';
import 'signed_logo.dart';

const _uiFont = 'IBMPlexSansArabic';

/// بطاقة المشاركة 1080×1350 (DESIGN §4). خلفية فاتحة دائماً وألوان الوضع الفاتح ثابتة.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  static const double width = 1080;
  static const double height = 1350;
  static const double margin = 64;

  final ShareCardData data;

  static const _colors = AppColors.light;

  TextStyle _t(double size, FontWeight w, Color c) =>
      TextStyle(fontFamily: _uiFont, fontSize: size, fontWeight: w, color: c, height: 1.25);

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final hasCafe = data.hasCafe;
    // بلا مقهى/موقع: الصورة أطول قليلاً وتصعد بقية العناصر (القيد: الدرجة لا تصطدم بالملاحظات).
    final imageH = hasCafe ? 560.0 : 584.0;
    final imageBottom = margin + imageH;
    final circleTop = imageBottom - 100;
    const notesTop = 820.0;
    final typeTop = hasCafe ? 650.0 : imageBottom + (notesTop - imageBottom - 56) / 2;
    const textStart = 300.0; // كتلة النص: x 64–780 في RTL (طولها 716) وتنعكس في LTR
    const textWidth = 716.0;

    return Directionality(
      textDirection: data.textDirection,
      child: DefaultTextStyle(
        style: _t(30, FontWeight.w400, c.ink),
        child: SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: c.bg,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. صورة الفحص
                Positioned(
                  left: margin,
                  top: margin,
                  width: width - 2 * margin,
                  height: imageH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RawImage(image: data.photo, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                  ),
                ),
                // 2. الدرجة
                PositionedDirectional(
                  start: margin,
                  top: circleTop,
                  width: 200,
                  height: 200,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: data.scoreColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bg, width: 6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(data.scoreLabel,
                                maxLines: 1, style: _t(64, FontWeight.w700, Colors.white).copyWith(height: 1.1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 3. المحمصة/النوع
                PositionedDirectional(
                  start: textStart,
                  top: typeTop,
                  width: textWidth,
                  height: 56,
                  child: Text(data.typeLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(40, FontWeight.w600, c.ink)),
                ),
                // 4. المقهى والموقع
                if (hasCafe)
                  PositionedDirectional(
                    start: textStart,
                    top: 714,
                    width: textWidth,
                    height: 86,
                    child: _CafeBlock(data: data, style: _t(32, FontWeight.w400, c.ink), link: _t(26, FontWeight.w400, c.inkSecondary)),
                  ),
                // 5. الملاحظات الثلاث
                for (var i = 0; i < data.notes.length; i++)
                  PositionedDirectional(
                    start: margin,
                    top: notesTop + i * 68,
                    width: width - 2 * margin,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(data.notes[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(30, FontWeight.w400, c.ink)),
                        ),
                      ),
                    ),
                  ),
                // 6. التنبيه «تقديري» (إلزامي)
                PositionedDirectional(
                  start: margin,
                  top: 1032,
                  width: width - 2 * margin,
                  height: 60,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                    child: Center(
                      child: Text(data.disclaimer,
                          maxLines: 1, style: _t(28, FontWeight.w400, c.ink)),
                    ),
                  ),
                ),
                // 7. التذييل: اسم التطبيق جهة البداية، واللوقو الموقَّع جهة النهاية
                PositionedDirectional(
                  start: margin,
                  top: 1104,
                  height: SignedLogo.height,
                  width: 560 - 40,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(data.appName, style: _t(36, FontWeight.w600, c.inkSecondary)),
                  ),
                ),
                PositionedDirectional(
                  end: margin,
                  top: 1104,
                  width: SignedLogo.width,
                  height: SignedLogo.height,
                  child: SignedLogo(logo: data.logo, name: data.userName),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CafeBlock extends StatelessWidget {
  const _CafeBlock({required this.data, required this.style, required this.link});
  final ShareCardData data;
  final TextStyle style;
  final TextStyle link;

  @override
  Widget build(BuildContext context) {
    const pinWidth = 32.0 + 8;
    final name = data.cafeName!;
    final size = fitFontSize(
      text: name,
      style: style,
      maxWidth: 716 - pinWidth,
      max: 32,
      min: 26,
      textDirection: Directionality.of(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.place, size: 32, color: AppColors.light.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(fontSize: size)),
          ),
        ]),
        if (data.mapsDisplay != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: pinWidth),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(data.mapsDisplay!, maxLines: 1, overflow: TextOverflow.ellipsis, style: link),
              ),
            ),
          ),
      ],
    );
  }
}
