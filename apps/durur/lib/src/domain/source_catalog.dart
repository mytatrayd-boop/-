import 'record_meta.dart';
import 'tables.dart';

/// مصدر واحد في صفحة المصادر مع حالة اعتماد السجلات التي تستشهد به (D27).
class SourceEntry {
  SourceEntry(this.source);

  /// أول ظهور للمصدر (العنوان والمؤلف والسنة).
  final Source source;

  /// هل كل السجلات التي تستشهد به معتمدة؟
  bool approved = true;

  /// المراجعون الذين اعتمدوا سجلاته (بترتيب الظهور، بلا تكرار).
  final Set<String> reviewers = <String>{};
}

/// مصادر كل الجداول مجمّعة من حقول source/sources بلا تكرار (D27).
///
/// المصدر الواحد = العنوان والمؤلف والسنة؛ الصفحة والرابط لا يفرّقان، فمصدر
/// المدن الموحّد (GeoNames) يظهر مرة واحدة وإن اختلف رابط كل مدينة.
/// الترتيب ترتيب أول ظهور في [Tables.allRecords].
List<SourceEntry> collectSources(Tables tables) {
  final entries = <String, SourceEntry>{};
  for (final record in tables.allRecords) {
    for (final source in record.sources) {
      final key = '${source.title}\u0000${source.author}\u0000${source.year}';
      final entry = entries.putIfAbsent(key, () => SourceEntry(source));
      final approval = record.approval;
      if (!approval.isApproved) {
        entry.approved = false;
      } else if ((approval.reviewer ?? '').trim().isNotEmpty) {
        entry.reviewers.add(approval.reviewer!.trim());
      }
    }
  }
  return entries.values.toList();
}
