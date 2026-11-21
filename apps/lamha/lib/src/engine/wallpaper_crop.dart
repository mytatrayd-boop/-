/// قص لقطة الشاشة الرئيسية على موضع ودجت آيفون (طلب المالك ١١/١١/٢٠٢٦): آيفون لا يسمح بقراءة
/// الخلفية ولا بودجت شفافة، فتُرسم تحت الودجت القطعة التي خلفها تماماً من لقطة الشاشة.
///
/// الجدول بالنقاط لكل ارتفاع لقطة بالبكسل: مقاسا الودجت الكبيرة والمتوسطة، والهامش الأيسر، وبداية
/// الصفوف (أعلى، وسط، أسفل). القيم تقريبية وتُضبط بالسحب في شاشة القص.
library;

enum WidgetSize { large, medium }

enum WidgetSlot { top, middle, bottom }

typedef CropRect = ({double left, double top, double width, double height});

typedef _Device = ({
  double scale,
  double largeW,
  double largeH,
  double mediumH,
  double top,
  double middle,
  double bottom,
});

/// المفتاح ارتفاع اللقطة بالبكسل.
const Map<int, _Device> _devices = {
  // SE 2/3، و6/7/8 (375×667 @2)
  1334: (scale: 2, largeW: 321, largeH: 324, mediumH: 148, top: 30, middle: 206, bottom: 382),
  // SE 1 (320×568 @2)
  1136: (scale: 2, largeW: 292, largeH: 311, mediumH: 141, top: 29.5, middle: 199.5, bottom: 369.5),
  // Plus (414×736 @3)
  2208: (scale: 3, largeW: 348, largeH: 357, mediumH: 157, top: 38, middle: 232, bottom: 426),
  // XR و11 (414×896 @2)
  1792: (scale: 2, largeW: 360, largeH: 379, mediumH: 169, top: 80, middle: 290, bottom: 500),
  // X وXS و11 Pro (375×812 @3)
  2436: (scale: 3, largeW: 329, largeH: 345, mediumH: 155, top: 71, middle: 261, bottom: 451),
  // XS Max و11 Pro Max (414×896 @3)
  2688: (scale: 3, largeW: 360, largeH: 379, mediumH: 169, top: 76, middle: 286, bottom: 496),
  // 12/13 mini (360×780 @3)
  2340: (scale: 3, largeW: 329, largeH: 345, mediumH: 155, top: 70.7, middle: 252, bottom: 433.3),
  // 12/13/14 (390×844 @3)
  2532: (scale: 3, largeW: 338, largeH: 354, mediumH: 158, top: 77, middle: 273, bottom: 469),
  // 12/13 Pro Max و14 Plus (428×926 @3)
  2778: (scale: 3, largeW: 364, largeH: 382, mediumH: 170, top: 82, middle: 294, bottom: 506),
  // 14 Pro و15 و15 Pro و16 (393×852 @3)
  2556: (scale: 3, largeW: 338, largeH: 354, mediumH: 158, top: 90, middle: 286, bottom: 482),
  // 14 Pro Max و15 Plus و15 Pro Max و16 Plus (430×932 @3)
  2796: (scale: 3, largeW: 364, largeH: 382, mediumH: 170, top: 94, middle: 306, bottom: 518),
};

/// المواضع المتاحة: الكبيرة تأخذ صفين من ثلاثة، فـ«أسفل» لها يبدأ من الوسط.
List<WidgetSlot> slotsFor(WidgetSize size) => size == WidgetSize.large
    ? const [WidgetSlot.top, WidgetSlot.bottom]
    : WidgetSlot.values;

/// مستطيل القص بالبكسل للقطة [width]×[height]. جهاز غير معروف: تقدير من نسب آيفون 12.
CropRect cropRect(int width, int height, WidgetSize size, WidgetSlot slot) {
  final d = _devices[height];
  if (d == null) return _estimate(width, height, size, slot);
  final w = d.largeW * d.scale;
  final h = (size == WidgetSize.large ? d.largeH : d.mediumH) * d.scale;
  final rowTop = switch ((size, slot)) {
    (WidgetSize.large, WidgetSlot.top) => d.top,
    (WidgetSize.large, _) => d.middle,
    (_, WidgetSlot.top) => d.top,
    (_, WidgetSlot.middle) => d.middle,
    (_, WidgetSlot.bottom) => d.bottom,
  };
  return clampRect((left: (width - w) / 2, top: rowTop * d.scale, width: w, height: h), width, height);
}

/// تقدير بنسب آيفون 12 (390×844): العرض ٨٦٧٪٠ من اللقطة، والارتفاعات والمواضع بالنسبة نفسها.
CropRect _estimate(int width, int height, WidgetSize size, WidgetSlot slot) {
  const ref = (w: 390.0, h: 844.0);
  final sx = width / ref.w;
  final sy = height / ref.h;
  final w = 338 * sx;
  final h = (size == WidgetSize.large ? 354 : 158) * sx;
  final top = switch ((size, slot)) {
    (WidgetSize.large, WidgetSlot.top) => 77.0,
    (WidgetSize.large, _) => 273.0,
    (_, WidgetSlot.top) => 77.0,
    (_, WidgetSlot.middle) => 273.0,
    (_, WidgetSlot.bottom) => 469.0,
  };
  return clampRect((left: (width - w) / 2, top: top * sy, width: w, height: h), width, height);
}

/// يبقي المستطيل داخل اللقطة (بعد السحب أيضاً).
CropRect clampRect(CropRect r, int width, int height) {
  final w = r.width.clamp(1.0, width.toDouble());
  final h = r.height.clamp(1.0, height.toDouble());
  return (
    left: r.left.clamp(0.0, width - w),
    top: r.top.clamp(0.0, height - h),
    width: w,
    height: h,
  );
}
