import 'package:durur/src/domain/city.dart';
import 'package:durur/src/domain/city_search.dart';
import 'package:durur/src/engine/table_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// الميزة 3 على cities.json الفعلي.
Future<void> main() async {
  final tables = await loadAssetTables();

  test('معيار 1: مدن كل دول الخليج الست موجودة', () {
    for (final country in Country.values) {
      expect(
        tables.cities.where((c) => c.country == country),
        isNotEmpty,
        reason: country.code,
      );
    }
    expect(tables.cities.length, greaterThanOrEqualTo(40));
  });

  test('السعودية بمناطقها: نجد والشرقية والحجاز والجنوب', () {
    final areas = {
      for (final c in tables.cities)
        if (c.country == Country.sa) c.area,
    };
    expect(areas, containsAll(['najd', 'eastern', 'hijaz', 'south']));
    for (final c in tables.cities.where((c) => c.country == Country.sa)) {
      expect(c.area, isNotNull, reason: c.id);
    }
  });

  test('معيار 2: كل مدينة مرتبطة بجدول منطقة موجود وبإحداثيات في الخليج', () {
    expect(const TableValidator().validate(tables).errors, isEmpty);
    for (final city in tables.cities) {
      expect(tables.region(city.regionId), isNotNull, reason: city.id);
      expect(tables.regionTables[city.regionId], isNotNull, reason: city.id);
      // صندوق تقريبي لدول الخليج الست.
      expect(city.lat, inInclusiveRange(16, 32.5), reason: city.id);
      expect(city.lon, inInclusiveRange(34, 60), reason: city.id);
      expect(city.source.title, isNotEmpty, reason: city.id);
      expect(city.source.url, startsWith('https://www.geonames.org/'),
          reason: city.id);
    }
  });

  test('الربط المؤقت (منطقة بلا جدول خاص) موثّق بملاحظة', () {
    for (final city in tables.cities) {
      // كل منطقة سعودية غير نجد، والمنطقة الرابعة المقترحة.
      final provisional = city.regionId == 'region4' ||
          (city.country == Country.sa && city.area != 'najd');
      if (provisional) {
        expect(city.regionNote, isNotNull, reason: city.id);
      }
    }
  });

  test('قرار المالك: كل مدن السعودية على جدول نجد (عرض السعودية)', () {
    final saudi = tables.cities.where((c) => c.country == Country.sa);
    expect(saudi, isNotEmpty);
    for (final city in saudi) {
      expect(city.regionId, 'najd', reason: city.id);
    }
    // الشرقية وحفر الباطن بملاحظة القرار؛ البحرين وقطر تبقيان على region4.
    for (final id in [
      'dammam', 'khobar', 'dhahran', 'qatif', 'al_ahsa', 'jubail',
      'hafar_al_batin',
    ]) {
      expect(tables.city(id)!.regionNote, contains('قرار عرض السعودية'),
          reason: id);
    }
    for (final city in tables.cities.where(
        (c) => c.country == Country.bh || c.country == Country.qa)) {
      expect(city.regionId, 'region4', reason: city.id);
    }
  });

  test('معيار 3: الرياض ← نجد، الكويت ← الكويت، مسقط ← الإمارات وعُمان', () {
    expect(tables.city('riyadh')!.regionId, 'najd');
    expect(tables.city('kuwait_city')!.regionId, 'kuwait');
    expect(tables.city('muscat')!.regionId, 'uae_oman');
  });

  test('المعرّفات فريدة، وكل اسم يُعثر عليه بالبحث بعد التطبيع', () {
    final ids = tables.cities.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final city in tables.cities) {
      expect(
        searchCities(tables.cities, query: normalizeArabic(city.name.ar)),
        contains(same(city)),
        reason: city.id,
      );
    }
  });

  test('الإحداثيات مطابقة لمراكز المدن المعروفة (±0.2°)', () {
    void near(String id, double lat, double lon) {
      final c = tables.city(id)!;
      expect(c.lat, closeTo(lat, 0.2), reason: id);
      expect(c.lon, closeTo(lon, 0.2), reason: id);
    }

    near('riyadh', 24.69, 46.72);
    near('kuwait_city', 29.37, 47.98);
    near('muscat', 23.58, 58.41);
    near('doha', 25.29, 51.53);
    near('manama', 26.23, 50.59);
    near('dubai', 25.08, 55.31);
    near('jeddah', 21.49, 39.19);
  });
}
