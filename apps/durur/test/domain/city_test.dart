import 'package:durur/src/domain/city.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/table_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart' as fx;

Map<String, Object?> cityJson(
  String id, {
  String region = 'a',
  String country = 'SA',
  Object lat = 24.7,
  Object lon = 46.7,
}) =>
    {
      'id': id,
      'name': {'ar': id},
      'country': country,
      'lat': lat,
      'lon': lon,
      'regionId': region,
      'source': fx.fixtureSource,
      'approval': fx.approved,
    };

Tables tablesWithCities(List<Object?> cities) => Tables.fromJson(
      metaJson: {'schemaVersion': 1, 'dataVersion': 'fixture'},
      regionsJson: [for (final id in ['a', 'b', 'c', 'd']) fx.region(id)],
      itemsJson: fx.fixtureItems(),
      regionTablesJson: {
        for (final id in ['a', 'b', 'c', 'd']) id: fx.regionTable(id),
      },
      citiesJson: cities,
    );

void main() {
  group('City.fromJson', () {
    test('يقرأ الحقول، والإحداثيات الصحيحة تُقبل كأعداد', () {
      final city = City.fromJson(
        {...cityJson('x', lat: 24, lon: 46), 'area': 'najd', 'regionNote': 'ن'},
        'cities.json[0]',
      );
      expect(city.id, 'x');
      expect(city.country, Country.sa);
      expect(city.lat, 24.0);
      expect(city.lon, 46.0);
      expect(city.area, 'najd');
      expect(city.regionNote, 'ن');
      expect(city.recordPath, 'cities.json[x]');
      expect(city.approval.isApproved, isTrue);
    });

    test('دولة غير معروفة أو حقل ناقص ← خطأ واضح', () {
      expect(
        () => City.fromJson(cityJson('x', country: 'FR'), 'c'),
        throwsFormatException,
      );
      expect(
        () => City.fromJson({...cityJson('x')}..remove('regionId'), 'c'),
        throwsFormatException,
      );
      expect(
        () => City.fromJson(cityJson('x', lat: '24'), 'c'),
        throwsFormatException,
      );
    });
  });

  group('Tables والمدقق', () {
    test('المدن تُحمَّل ويُبحث عنها بالمعرّف، وتدخل في بوابة الاعتماد', () {
      final tables = tablesWithCities([cityJson('x'), cityJson('y')]);
      expect(tables.cities.map((c) => c.id), ['x', 'y']);
      expect(tables.city('y')?.id, 'y');
      expect(tables.city('z'), isNull);
      expect(const TableValidator().validate(tables).errors, isEmpty);

      final draft = tablesWithCities([
        {...cityJson('x'), 'approval': fx.draft},
      ]);
      expect(draft.hasUnapproved, isTrue);
      expect(
        const TableValidator().validate(draft, release: true).errors.join(),
        contains('cities.json[x]'),
      );
    });

    test('مدينة بمنطقة غير موجودة ← خطأ', () {
      final tables = tablesWithCities([cityJson('x', region: 'nowhere')]);
      expect(
        const TableValidator().validate(tables).errors.join(),
        contains('cities.json[x]'),
      );
    });

    test('معرّف مدينة مكرر ← خطأ', () {
      final tables = tablesWithCities([cityJson('x'), cityJson('x')]);
      expect(
        const TableValidator().validate(tables).errors.join(),
        contains('معرّف مدينة مكرر'),
      );
    });

    test('إحداثيات خارج النطاق ← خطأ', () {
      final tables = tablesWithCities([cityJson('x', lat: 95)]);
      expect(
        const TableValidator().validate(tables).errors.join(),
        contains('إحداثيات'),
      );
    });
  });
}
