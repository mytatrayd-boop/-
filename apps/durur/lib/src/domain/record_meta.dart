import 'json_utils.dart';

/// المرجع المنشور لسجل بيانات.
class Source {
  const Source({required this.title, this.author, this.year, this.page, this.url});

  factory Source.fromJson(Object? json, String where) {
    final map = asObject(json, '$where.source');
    final title = readField<String>(map, 'title', '$where.source');
    if (title.trim().isEmpty) {
      throw FormatException('$where.source: العنوان فارغ.');
    }
    return Source(
      title: title,
      author: readOptional<String>(map, 'author', '$where.source'),
      year: readOptional<int>(map, 'year', '$where.source'),
      page: readOptional<String>(map, 'page', '$where.source'),
      url: readOptional<String>(map, 'url', '$where.source'),
    );
  }

  final String title;
  final String? author;
  final int? year;
  final String? page;
  final String? url;
}

enum ApprovalStatus {
  draft,
  approved;

  static ApprovalStatus parse(String value, String where) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    throw FormatException('$where: حالة اعتماد غير معروفة "$value" '
        '(المسموح: draft، approved).');
  }
}

/// حالة اعتماد السجل من المراجع (شرط الإطلاق: كل السجلات approved).
class Approval {
  const Approval({required this.status, this.reviewer, this.date});

  factory Approval.fromJson(Object? json, String where) {
    final map = asObject(json, '$where.approval');
    return Approval(
      status: ApprovalStatus.parse(
          readField<String>(map, 'status', '$where.approval'),
          '$where.approval'),
      reviewer: readOptional<String>(map, 'reviewer', '$where.approval'),
      date: readOptional<String>(map, 'date', '$where.approval'),
    );
  }

  final ApprovalStatus status;
  final String? reviewer;
  final String? date;

  bool get isApproved => status == ApprovalStatus.approved;
}

/// سجل له مصدر وحالة اعتماد (يستخدمه المدقق).
abstract interface class Sourced {
  String get recordPath;
  List<Source> get sources;
  Approval get approval;
}
