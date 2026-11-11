import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/wallpaper_crop.dart';

void main() {
  test('آيفون SE: الكبيرة أعلى الشاشة بمقاسها (٣٢١×٣٢٤ نقطة @2) وفي منتصفها أفقياً', () {
    final r = cropRect(750, 1334, WidgetSize.large, WidgetSlot.top);
    expect(r, (left: 54.0, top: 60.0, width: 642.0, height: 648.0));
  });

  test('الكبيرة «أسفل» تبدأ من صف الوسط، والمتوسطة لها ثلاثة مواضع', () {
    expect(slotsFor(WidgetSize.large), [WidgetSlot.top, WidgetSlot.bottom]);
    expect(slotsFor(WidgetSize.medium), WidgetSlot.values);
    expect(cropRect(750, 1334, WidgetSize.large, WidgetSlot.bottom).top, 412);
    final m = cropRect(1170, 2532, WidgetSize.medium, WidgetSlot.bottom);
    expect((m.width, m.height, m.top), (1014.0, 474.0, 1407.0));
  });

  test('جهاز غير معروف: تقدير داخل اللقطة دائماً', () {
    for (final size in WidgetSize.values) {
      for (final slot in slotsFor(size)) {
        final r = cropRect(1206, 2622, size, slot);
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.top + r.height, lessThanOrEqualTo(2622));
        expect(r.left + r.width, lessThanOrEqualTo(1206));
      }
    }
  });

  test('السحب لا يُخرج الإطار من اللقطة', () {
    final r = clampRect((left: -50, top: 2000, width: 642, height: 648), 750, 1334);
    expect(r, (left: 0.0, top: 1334.0 - 648, width: 642.0, height: 648.0));
  });
}
