import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/widget_layout.dart';

/// الترتيب الافتراضي بلقطة المالك (١٨ نوفمبر ٢٠٢٦): اليوم فوق الساعة، والموقع والحرارة في الوسط،
/// والميلادي فوق الهجري، ثم المواقيت، ثم الإيداعات، ثم الفصل والموسم، والبوصلة عائمة في أسفل الوسط.
void main() {
  TileLayout of(WidgetElement e) => defaultLayout.firstWhere((t) => t.id == e);

  test('العناصر الظاهرة ومواضعها', () {
    final rects = rectsOf(defaultLayout);
    expect(rects[WidgetElement.weekday], const GridRect(0, 0, 2, 1));
    expect(rects[WidgetElement.clock], const GridRect(0, 1, 2, 2));
    expect(rects[WidgetElement.cityTemp], const GridRect(2, 0, 2, 2));
    expect(rects[WidgetElement.gregorian], const GridRect(4, 0, 2, 1));
    expect(rects[WidgetElement.hijri], const GridRect(4, 1, 2, 1));
    expect(rects[WidgetElement.prayerTimes], const GridRect(0, 3, 6, 2));
    expect(rects[WidgetElement.deposit], const GridRect(0, 5, 6, 2));
    expect(rects[WidgetElement.season], const GridRect(0, 7, 2, 1));
    expect(rects[WidgetElement.tradSeason], const GridRect(4, 7, 2, 1));
    expect(rects.containsKey(WidgetElement.qibla), isFalse, reason: 'البوصلة عائمة خارج الرصّ');
  });

  test('البوصلة عائمة في وسط أسفل الودجت بحجم كبير', () {
    final q = of(WidgetElement.qibla);
    expect(q.visible, isTrue);
    expect(q.float, isNotNull);
    final f = q.float!;
    expect(f.x + f.w / 2, closeTo(0.5, 0.01), reason: 'في الوسط');
    expect(f.y + f.h, closeTo(1.0, 0.01), reason: 'في أسفل الودجت');
    expect(q.iconScale, 5.0);
  });

  test('كل المزايا باقية: العناصر كلها موجودة (الظاهر والمخفي)، والتخطيط يُقسَم شجرة قص', () {
    expect(defaultLayout.map((t) => t.id).toSet(), WidgetElement.values.toSet());
    expect(defaultLayout.length, WidgetElement.values.length);
    expect(cutTree(rectsOf(defaultLayout)), isNotNull);
    expect(of(WidgetElement.dayWeather).visible, isFalse);
  });

  test('من لم يغيّر الترتيب السابق ينتقل إلى الجديد، والمخصص يبقى', () {
    expect(migrateLayout(previousDefaultLayout), defaultLayout);
    final custom = [
      for (final t in previousDefaultLayout)
        t.id == WidgetElement.clock ? t.copyWith(fontScale: 1.5) : t,
    ];
    expect(migrateLayout(custom).firstWhere((t) => t.id == WidgetElement.clock).fontScale, 1.5);
  });
}
