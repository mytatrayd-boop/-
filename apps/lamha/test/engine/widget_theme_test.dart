import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/schedule.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:lamha/src/engine/widget_theme.dart';

import '../helpers.dart';

void main() {
  test('السمات الثماني، والأسود افتراضي وللمجهول (الميزة ٦)', () {
    expect(WidgetTheme.values.map((t) => t.name),
        ['black', 'gold', 'green', 'blue', 'purple', 'pink', 'gray', 'system']);
    expect(WidgetTheme.byName(null), WidgetTheme.black);
    expect(WidgetTheme.byName('nope'), WidgetTheme.black);
    expect(WidgetTheme.black.background, 0xFF000000);
    expect(WidgetTheme.black.accent, 0xFFD6AA5C);
    expect(WidgetTheme.byName('pink'), WidgetTheme.pink);
    expect(WidgetTheme.gold.accent, 0xFFD6AA5C);
  });

  test('ألوان النظام للسمة system فقط، وبدونها الذهبي', () {
    const sys = (accent: 0xFF112233, background: 0xFF000011);
    expect(themeColors(WidgetTheme.system, sys), sys);
    expect(themeColors(WidgetTheme.system, null),
        (accent: WidgetTheme.gold.accent, background: WidgetTheme.gold.background));
    expect(themeColors(WidgetTheme.blue, sys),
        (accent: WidgetTheme.blue.accent, background: WidgetTheme.blue.background));
  });

  test('الجدول يحمل السمة ومفتاح الإشعار', () {
    final s = buildSchedule(
      DateTime.utc(2026, 10, 19, 9),
      Settings(
          latitude: 24.69,
          longitude: 46.72,
          cityName: 'الرياض',
          deposits: {'salary'},
          theme: WidgetTheme.purple,
          lockNotification: true),
      loadEngineDataFromFiles(),
      days: 1,
    );
    expect(s['theme'], {
      'id': 'purple',
      'accent': WidgetTheme.purple.accent,
      'background': WidgetTheme.purple.background,
    });
    expect(s['lockNotification'], isTrue);
    final dep = ((s['days']! as List).first as Map)['deposits'] as List;
    expect((dep.first as Map)['afterText'], 'بعد ٨ أيام');
  });

  test('خلفية أيقونة القبلة: لون الحلقة معتّماً إلى ٢٨٪ (الحالات نفسها في LamhaLogicTest.kt)', () {
    expect(qiblaIconBackground(0xFFD6AA5C), 0xFF3C301A);
    expect(qiblaIconBackground(0xFF7FB2E5), 0xFF243240);
    expect(qiblaIconBackground(0xFFFFFFFF), 0xFF474747);
  });
}
