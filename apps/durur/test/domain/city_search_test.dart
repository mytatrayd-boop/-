import 'package:durur/src/domain/city.dart';
import 'package:durur/src/domain/city_search.dart';
import 'package:durur/src/domain/localized_text.dart';
import 'package:durur/src/domain/record_meta.dart';
import 'package:flutter_test/flutter_test.dart';

City _city(String id, String name, Country country) => City(
      id: id,
      name: LocalizedText({'ar': name}),
      country: country,
      lat: 0,
      lon: 0,
      regionId: 'r',
      source: const Source(title: 't'),
      approval: const Approval(status: ApprovalStatus.draft),
    );

void main() {
  group('normalizeArabic', () {
    test('الهمزات: أ إ آ ٱ ← ا، ؤ ← و، ئ ← ي', () {
      expect(normalizeArabic('الأحساء'), normalizeArabic('الاحساء'));
      expect(normalizeArabic('إبراهيم'), 'ابراهيم');
      expect(normalizeArabic('آل'), 'ال');
      expect(normalizeArabic('ٱلله'), 'الله');
      expect(normalizeArabic('مؤتة'), 'موته');
      expect(normalizeArabic('حائل'), 'حايل');
    });

    test('التاء المربوطة والألف المقصورة', () {
      expect(normalizeArabic('المجمعة'), 'المجمعه');
      expect(normalizeArabic('مكة المكرمة'), normalizeArabic('مكه المكرمه'));
      expect(normalizeArabic('مصطفى'), 'مصطفي');
    });

    test('إزالة التشكيل والتطويل وتوحيد المسافات', () {
      expect(normalizeArabic('الرِّيَاض'), 'الرياض');
      expect(normalizeArabic('الريـــاض'), 'الرياض');
      expect(normalizeArabic('  مدينة   الكويت '), 'مدينه الكويت');
    });
  });

  group('searchCities', () {
    final cities = [
      _city('riyadh', 'الرياض', Country.sa),
      _city('al_ahsa', 'الأحساء', Country.sa),
      _city('kuwait_city', 'مدينة الكويت', Country.kw),
      _city('doha', 'الدوحة', Country.qa),
      _city('hamad_town', 'مدينة حمد', Country.bh),
    ];
    List<String> ids(List<City> list) => [for (final c in list) c.id];

    test('البحث الفارغ يُرجع الكل بالترتيب الأصلي', () {
      expect(ids(searchCities(cities)), ids(cities));
      expect(ids(searchCities(cities, query: '   ')), ids(cities));
    });

    test('بحث بالاسم العربي، وجزء من الاسم يكفي', () {
      expect(ids(searchCities(cities, query: 'الرياض')), ['riyadh']);
      expect(ids(searchCities(cities, query: 'رياض')), ['riyadh']);
      expect(ids(searchCities(cities, query: 'مدينة')),
          ['kuwait_city', 'hamad_town']);
    });

    test('«الاحساء» = «الأحساء»، و«الدوحه» = «الدوحة»، والتشكيل لا يؤثر', () {
      expect(ids(searchCities(cities, query: 'الاحساء')), ['al_ahsa']);
      expect(ids(searchCities(cities, query: 'الدوحه')), ['doha']);
      expect(ids(searchCities(cities, query: 'الرِّياض')), ['riyadh']);
    });

    test('لا نتائج', () {
      expect(searchCities(cities, query: 'لندن'), isEmpty);
    });

    test('التصفية بالدولة مع البحث وبدونه', () {
      expect(ids(searchCities(cities, country: Country.sa)),
          ['riyadh', 'al_ahsa']);
      expect(ids(searchCities(cities, query: 'مدينة', country: Country.bh)),
          ['hamad_town']);
      expect(searchCities(cities, query: 'الرياض', country: Country.qa),
          isEmpty);
    });
  });
}
