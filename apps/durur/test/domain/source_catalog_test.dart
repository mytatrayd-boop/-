import 'package:durur/src/domain/source_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';
import '../helpers/app_harness.dart';

/// D27: مصادر الجداول مجمّعة بلا تكرار مع حالة اعتمادها.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final assets = await loadAssetTables();

  test(
    'البيانات المضمّنة: GeoNames مرة واحدة رغم 67 مدينة، والهجري، ولا تكرار',
    () {
      final entries = collectSources(assets);
      final titles = entries.map((e) => e.source.title).toList();
      expect(titles.toSet().length, titles.length);
      expect(titles.where((t) => t.startsWith('GeoNames')).length, 1);
      expect(titles.any((t) => t.contains('van Gent')), isTrue);
      expect(assets.cities.length, greaterThan(1));
      // البيانات الحالية مسودة كلها.
      expect(entries.every((e) => !e.approved), isTrue);
    },
  );

  test(
    'المعتمد يذكر مراجعيه بلا تكرار، وأي سجل مسودة يجعله «بانتظار الاعتماد»',
    () {
      final approvedOnly = collectSources(fixtureTables());
      expect(approvedOnly.single.source.title, 'fixture');
      expect(approvedOnly.single.approved, isTrue);
      expect(approvedOnly.single.reviewers, {'test'});

      final mixed = collectSources(
        fixtureTables(
          edit: (t, _, _) =>
              ((t['a']! as Map<String, Object?>)['durur']! as List)[0] = dar(
                '01-05',
                1,
                'أ',
                's1',
                approval: draft,
              ),
        ),
      );
      expect(mixed.single.approved, isFalse);
    },
  );
}
