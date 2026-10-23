import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/engine/arabic.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'app_helpers.dart';

/// الميزة ٦: تصميم المالك ٣، والترحيل، وإعداد «الأرقام».
void main() {
  final city = parseCities(readAsset('assets/cities.json')).first;

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  group('الترحيل', () {
    testWidgets('الترتيب الافتراضي السابق كما هو ← الترتيب الجديد', (tester) async {
      final old = LamhaSettings.defaults(city, {'salary'})
          .copyWith(layout: legacyDefaultLayout)
          .toJson();
      final bridge = await pumpApp(tester, prefs: {LamhaSettings.prefsKey: jsonEncode(old)});
      expect([for (final t in bridge.last['layout'] as List) (t as Map)['id']],
          [for (final t in defaultLayout) t.id.name]);
      expect(find.byKey(const Key('tile-prayerTimes')), findsOneWidget);
      expect(find.byKey(const Key('tile-prayer')), findsNothing);
    });

    testWidgets('ترتيب مخصص يبقى، والعناصر الجديدة في آخره مخفية', (tester) async {
      final custom = [
        legacyDefaultLayout[3].copyWith(span: 3),
        ...legacyDefaultLayout.where((t) => t.id != WidgetElement.prayer),
      ];
      final old = LamhaSettings.defaults(city, {'salary'}).copyWith(layout: custom).toJson();
      final bridge = await pumpApp(tester, prefs: {LamhaSettings.prefsKey: jsonEncode(old)});
      final layout = (bridge.last['layout'] as List).cast<Map>();
      expect(layout.take(8).map((t) => t['id']), custom.map((t) => t.id.name));
      expect(layout.skip(8).map((t) => t['id']),
          ['dayWeather', 'hijri', 'gregorian', 'prayerTimes', 'tradPoints']);
      expect(layout.skip(8).every((t) => t['visible'] == false), isTrue);
      expect(find.byKey(const Key('tile-prayer')), findsOneWidget);
      expect(find.byKey(const Key('tile-prayerTimes')), findsNothing);
    });
  });

  group('الأرقام', () {
    testWidgets('عربية افتراضياً، والإنجليزية تُحفظ في الإعدادات والجدول وتتبعها المعاينة',
        (tester) async {
      final bridge = await pumpApp(tester, weather: FakeWeather(temp: 31.4));
      expect(bridge.last['digits'], 'arabic');
      expect(text(tester, 'preview-temp'), '\u2066٣١°\u2069');
      expect(text(tester, 'preview-clock'), '١٢:٠٠');
      final chip = find.byKey(const Key('digits-latin'));
      expect(find.text('إنجليزية (123)'), findsOneWidget);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(bridge.last['digits'], 'latin');
      expect(RegExp('[٠-٩]').hasMatch(jsonEncode(bridge.last)), isFalse);
      expect(text(tester, 'preview-temp'), '\u206631°\u2069');
      expect(text(tester, 'preview-clock'), '12:00');
      expect(text(tester, 'preview-hijri'), contains('1448'));
      // الوقت قد يُخفى بخط الاختبار العريض؛ نصه من الجدول.
      final asr = (((bridge.last['days'] as List).first as Map)['prayers'] as Map)['asr'] as Map;
      expect(asr['text'], matches(RegExp(r'^\d+:\d\d [صم]$')));
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
      expect(saved['digits'], 'latin');
      expect(LamhaSettings.fromJson(saved.cast<String, dynamic>()).digits, DigitStyle.latin);
      // إعدادات قديمة بلاه = عربية.
      final old = (saved.cast<String, dynamic>())..remove('digits');
      expect(LamhaSettings.fromJson(old).digits, DigitStyle.arabic);
    });
  });

  testWidgets('الإيداعات بعرض ١: عمود واحد، وبعرض ٣: حتى ثلاثة', (tester) async {
    final s = LamhaSettings.defaults(city, {'salary', 'citizen_account', 'housing_support'}).copyWith(
      layout: [
        for (final t in defaultLayout) t.id == WidgetElement.deposit ? t.copyWith(span: 1) : t,
      ],
    );
    await pumpApp(tester, prefs: {LamhaSettings.prefsKey: s.encode()});
    expect(find.byKey(const Key('deposit-name-0')), findsOneWidget);
    expect(find.byKey(const Key('deposit-name-1')), findsNothing);
  });
}
