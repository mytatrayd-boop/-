import '../domain/city.dart';
import '../domain/item.dart';
import '../domain/month_day.dart';
import '../domain/region_table.dart';
import '../domain/tables.dart';
import '../hijri/hijri_table_validator.dart';

/// نتيجة التحقق من الجداول.
class ValidationReport {
  const ValidationReport(this.errors, this.warnings);

  final List<String> errors;
  final List<String> warnings;

  bool get isValid => errors.isEmpty;
}

/// يتحقق من صحة الجداول (ARCHITECTURE §4). مع [release] يصبح أي سجل
/// غير معتمد خطأً (بوابة الإطلاق، D16).
class TableValidator {
  const TableValidator({this.expectedRegionCount = 4});

  /// عدد المناطق المطلوب في النسخة الأولى (SPEC قسم 3).
  final int expectedRegionCount;

  /// أقصى عدد أسطر للتعريف (SPEC الميزة 7).
  static const maxDefinitionLines = 2;

  /// بادئة dataVersion للبيانات التجريبية؛ ممنوعة في الإطلاق.
  static const sampleDataPrefix = 'sample';

  ValidationReport validate(Tables tables, {bool release = false}) {
    final errors = <String>[];
    final warnings = <String>[];

    _checkRegions(tables, errors);
    _checkItems(tables, errors);
    _checkCities(tables, errors);
    for (final table in tables.regionTables.values) {
      _checkRegionTable(table, tables, errors);
    }
    _checkCountryDurur(tables, release ? errors : warnings);
    final hijri = tables.hijri;
    if (hijri != null) {
      errors.addAll(const HijriTableValidator().validate(hijri));
    }

    final unapproved = [
      for (final r in tables.allRecords)
        if (!r.approval.isApproved) r.recordPath,
    ];
    if (unapproved.isNotEmpty) {
      final message =
          '${unapproved.length} سجل غير معتمد من المراجع '
          '(أولها: ${unapproved.first}).';
      (release ? errors : warnings).add(message);
    }

    if (release) {
      // الاعتماد يتطلب اسم المراجع وتاريخ الاعتماد (SPEC قسم 3، ARCHITECTURE §4).
      final incomplete = [
        for (final r in tables.allRecords)
          if (r.approval.isApproved &&
              ((r.approval.reviewer ?? '').trim().isEmpty ||
                  (r.approval.date ?? '').trim().isEmpty))
            r.recordPath,
      ];
      if (incomplete.isNotEmpty) {
        errors.add(
          '${incomplete.length} سجل معتمد بلا اسم المراجع أو '
          'تاريخ الاعتماد (أولها: ${incomplete.first}).',
        );
      }
      if (tables.meta.dataVersion.startsWith(sampleDataPrefix)) {
        errors.add(
          'meta.json: dataVersion "${tables.meta.dataVersion}" '
          'بيانات تجريبية، ممنوع الإطلاق بها.',
        );
      }
    }
    return ValidationReport(errors, warnings);
  }

  void _checkRegions(Tables tables, List<String> errors) {
    final ids = tables.regions.map((r) => r.id).toList();
    if (ids.length != expectedRegionCount) {
      errors.add(
        'regions.json: عدد المناطق ${ids.length} '
        'والمطلوب $expectedRegionCount.',
      );
    }
    _checkUnique(ids, 'regions.json: معرّف منطقة مكرر', errors);
    for (final id in ids.toSet()) {
      if (!tables.regionTables.containsKey(id)) {
        errors.add('regions/$id.json: جدول المنطقة مفقود.');
      }
    }
    for (final id in tables.regionTables.keys) {
      if (!ids.contains(id)) {
        errors.add('regions/$id.json: منطقة غير موجودة في regions.json.');
      }
    }
  }

  /// كل مدينة: معرّف فريد، منطقة موجودة، إحداثيات صالحة (ARCHITECTURE §4).
  void _checkCities(Tables tables, List<String> errors) {
    _checkUnique(
      tables.cities.map((c) => c.id).toList(),
      'cities.json: معرّف مدينة مكرر',
      errors,
    );
    final regionIds = tables.regions.map((r) => r.id).toSet();
    for (final city in tables.cities) {
      if (!regionIds.contains(city.regionId)) {
        errors.add(
          '${city.recordPath}: المنطقة "${city.regionId}" غير موجودة '
          'في regions.json.',
        );
      }
      if (city.lat < -90 ||
          city.lat > 90 ||
          city.lon < -180 ||
          city.lon > 180) {
        errors.add('${city.recordPath}: إحداثيات خارج النطاق.');
      }
    }
  }

  void _checkItems(Tables tables, List<String> errors) {
    _checkUnique(
      tables.itemList.map((i) => i.id).toList(),
      'items.json: معرّف عنصر مكرر',
      errors,
    );
    for (final item in tables.itemList) {
      final lines = item.definition.ar.trim().split('\n').length;
      if (lines > maxDefinitionLines) {
        errors.add(
          '${item.recordPath}: التعريف $lines أسطر '
          '(الحد $maxDefinitionLines).',
        );
      }
      if (item.sources.isEmpty) {
        errors.add('${item.recordPath}: لا يوجد مصدر.');
      }
    }
  }

  void _checkRegionTable(
    RegionTable table,
    Tables tables,
    List<String> errors,
  ) {
    final where = 'regions/${table.regionId}.json';

    if (table.hasDurur) {
      _checkContinuous(
        table.durur.map((r) => r.start).toList(),
        '$where:durur',
        errors,
      );
    } else {
      // منطقة بلا درور (D50): «الجو المعتاد» ورموز الإطار من النجم الحالي،
      // فيلزم لكل نجم فيها `weather` غير فارغ.
      for (final r in table.stars) {
        final item = tables.items[r.itemId];
        if (item != null && item.weather.isEmpty) {
          errors.add(
            '${r.recordPath}: المنطقة بلا درور، والنجم "${r.itemId}" '
            'بلا weather (مصدر الجو المعتاد فيها).',
          );
        }
      }
    }
    _checkContinuous(
      table.majorSeasons.map((r) => r.start).toList(),
      '$where:majorSeasons',
      errors,
    );
    _checkContinuous(
      table.stars.map((r) => r.start).toList(),
      '$where:stars',
      errors,
    );

    for (final r in table.majorSeasons) {
      _checkItemRef(
        r.itemId,
        ItemKind.majorSeason,
        r.recordPath,
        tables,
        errors,
      );
    }
    for (final r in table.stars) {
      _checkItemRef(r.itemId, ItemKind.star, r.recordPath, tables, errors);
    }
    for (final r in table.weatherSeasons) {
      _checkItemRef(
        r.itemId,
        ItemKind.weatherSeason,
        r.recordPath,
        tables,
        errors,
      );
    }

    for (final dar in table.durur) {
      if (dar.number < 1) {
        errors.add('${dar.recordPath}: رقم الدَّرّ يجب أن يكون 1 أو أكثر.');
      }
      if (!_checkItemRef(
        dar.seasonId,
        ItemKind.majorSeason,
        dar.recordPath,
        tables,
        errors,
      )) {
        continue;
      }
      // الموسم المكتوب في الدَّرّ يطابق الموسم الكبير الفعّال يوم بدايته.
      final active = _activeAt(table.majorSeasons, dar.start);
      if (active != null && active.itemId != dar.seasonId) {
        errors.add(
          '${dar.recordPath}: seasonId "${dar.seasonId}" يخالف '
          'الموسم الكبير الفعّال يوم بدايته "${active.itemId}".',
        );
      }
    }

    _checkWeatherSeasonOverlap(table, where, errors);
  }

  /// قاعدة الدولة (D43، D50، ARCHITECTURE §18): كل منطقة تشير إليها مدينة
  /// سعودية بلا درور، وكل منطقة تشير إليها مدينة خليجية خارج السعودية
  /// بدرور. خطأ في الإطلاق، وتحذير في التطوير.
  void _checkCountryDurur(Tables tables, List<String> out) {
    final saudi = <String>{};
    final gulf = <String>{};
    for (final city in tables.cities) {
      (city.country == Country.sa ? saudi : gulf).add(city.regionId);
    }
    for (final id in saudi) {
      final table = tables.regionTables[id];
      if (table != null && table.hasDurur) {
        out.add(
          'regions/$id.json: منطقة سعودية فيها درور؛ '
          'السعودية بلا درور (D43).',
        );
      }
    }
    for (final id in gulf) {
      final table = tables.regionTables[id];
      if (table != null && !table.hasDurur) {
        out.add(
          'regions/$id.json: منطقة خليجية خارج السعودية بلا درور '
          '(D43: الدرور باقية في الخليج).',
        );
      }
    }
  }

  /// بدايات مرتبة تصاعدياً وفريدة وغير فارغة؛ الغطاء الكامل مضمون بالبناء (D6).
  void _checkContinuous(
    List<MonthDay> starts,
    String where,
    List<String> errors,
  ) {
    if (starts.isEmpty) {
      errors.add('$where: الطبقة فارغة.');
      return;
    }
    for (var i = 1; i < starts.length; i++) {
      if (!(starts[i - 1] < starts[i])) {
        errors.add(
          '$where: البدايات غير مرتبة أو مكررة عند '
          '${starts[i - 1]} ← ${starts[i]}.',
        );
      }
    }
  }

  bool _checkItemRef(
    String itemId,
    ItemKind kind,
    String where,
    Tables tables,
    List<String> errors,
  ) {
    final item = tables.items[itemId];
    if (item == null) {
      errors.add('$where: العنصر "$itemId" غير موجود في items.json.');
      return false;
    }
    if (item.kind != kind) {
      errors.add(
        '$where: العنصر "$itemId" نوعه ${item.kind.code} '
        'والمتوقع ${kind.code}.',
      );
      return false;
    }
    return true;
  }

  LayerRecord? _activeAt(List<LayerRecord> layer, MonthDay md) {
    if (layer.isEmpty) return null;
    final sorted = [...layer]..sort((a, b) => a.start.compareTo(b.start));
    LayerRecord? active;
    for (final r in sorted) {
      if (r.start <= md) active = r;
    }
    return active ?? sorted.last;
  }

  void _checkWeatherSeasonOverlap(
    RegionTable table,
    String where,
    List<String> errors,
  ) {
    // سنة غير كبيسة تمثّل كل (شهر، يوم) مرة واحدة.
    for (
      var d = DateTime.utc(2025, 1, 1);
      d.year == 2025;
      d = d.add(const Duration(days: 1))
    ) {
      final md = MonthDay.of(d);
      final hits = [
        for (final s in table.weatherSeasons)
          if (s.contains(md)) s.itemId,
      ];
      if (hits.length > 1) {
        errors.add(
          '$where:weatherSeasons: تداخل يوم $md بين ${hits.join('، ')}.',
        );
        return;
      }
    }
  }

  void _checkUnique(List<String> ids, String message, List<String> errors) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) errors.add('$message: $id');
    }
  }
}
