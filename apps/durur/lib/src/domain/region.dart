import 'json_utils.dart';
import 'localized_text.dart';
import 'record_meta.dart';

/// قاعدة 29 فبراير في جدول المنطقة (D7).
enum LeapDayRule {
  /// 29 فبراير يتبع دَرّ 28 فبراير، فيطول ذلك الدَّرّ يوماً.
  extendFeb28('extend_feb28');

  const LeapDayRule(this.code);
  final String code;

  static LeapDayRule parse(String code, String where) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    throw FormatException('$where: قاعدة 29 فبراير غير معروفة "$code".');
  }
}

class Region implements Sourced {
  const Region({
    required this.id,
    required this.name,
    required this.leapDayRule,
    required this.source,
    required this.approval,
  });

  factory Region.fromJson(Object? json, String where) {
    final map = asObject(json, where);
    final id = readField<String>(map, 'id', where);
    final w = '$where[$id]';
    return Region(
      id: id,
      name: LocalizedText.fromJson(map['name'], '$w.name'),
      leapDayRule:
          LeapDayRule.parse(readField<String>(map, 'leapDayRule', w), w),
      source: Source.fromJson(map['source'], w),
      approval: Approval.fromJson(map['approval'], w),
    );
  }

  final String id;
  final LocalizedText name;
  final LeapDayRule leapDayRule;
  final Source source;
  @override
  final Approval approval;

  @override
  String get recordPath => 'regions.json[$id]';

  @override
  List<Source> get sources => [source];
}
