import 'dart:convert';

import 'arabic.dart';

/// المواسم التراثية من `assets/seasons.json` (مسودة يراجعها المالك).
/// كل موسم يبدأ في يوم ميلادي ثابت، وينتهي في اليوم السابق لبداية التالي.

class TradSeason {
  const TradSeason({
    required this.id,
    required this.name,
    required this.startMonth,
    required this.startDay,
    required this.description,
    this.points = const [],
    this.opens,
  });

  final String id;
  final String name;
  final int startMonth;
  final int startDay;
  final String description;

  /// نقاط مربع «وصف الموسم» (الميزة ٦)، كل نقطة جملة.
  final List<String> points;

  /// الفصل الذي يبدأ بهذا الموسم (spring/summer/autumn/winter)، أو null.
  final String? opens;
}

class CurrentTradSeason {
  const CurrentTradSeason({
    required this.season,
    required this.next,
    required this.start,
    required this.end,
    required this.daysRemaining,
    required this.approval,
  });

  final TradSeason season;
  final TradSeason next;

  /// أول يوم في الموسم الحالي.
  final DateTime start;

  /// آخر يوم (شامل).
  final DateTime end;

  /// الأيام حتى بداية الموسم التالي.
  final int daysRemaining;
  final String approval;

  String get remainingText => remainingDaysText(daysRemaining);

  Map<String, Object> toJson() => {
        'id': season.id,
        'name': season.name,
        'description': season.description,
        'descriptionLine': tradDescriptionLine(season.name, season.description),
        'points': season.points,
        'start': isoDate(start),
        'end': isoDate(end),
        'next': {'id': next.id, 'name': next.name},
        'daysRemaining': daysRemaining,
        'remainingText': remainingText,
        'afterText': afterDaysText(daysRemaining),
        'approval': approval,
      };
}

class TradSeasonsTable {
  TradSeasonsTable(List<TradSeason> seasons, {this.approval = 'draft'})
      : seasons = List.unmodifiable(seasons) {
    if (seasons.isEmpty) throw const FormatException('seasons.json: فارغ.');
  }

  factory TradSeasonsTable.fromJsonString(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final list = [
      for (final s in j['seasons'] as List)
        _parse(s as Map<String, dynamic>),
    ]..sort((a, b) => (a.startMonth * 100 + a.startDay)
        .compareTo(b.startMonth * 100 + b.startDay));
    final approval =
        ((j['approval'] as Map<String, dynamic>?)?['status'] as String?) ??
            'draft';
    return TradSeasonsTable(list, approval: approval);
  }

  static TradSeason _parse(Map<String, dynamic> m) {
    final match =
        RegExp(r'^(\d{2})-(\d{2})$').firstMatch(m['start'] as String);
    if (match == null) {
      throw FormatException('seasons.json: بداية غير صالحة ${m['start']}.');
    }
    return TradSeason(
      id: m['id'] as String,
      name: m['name'] as String,
      startMonth: int.parse(match[1]!),
      startDay: int.parse(match[2]!),
      description: m['description'] as String,
      points: [...(m['points'] as List? ?? const []).cast<String>()],
      opens: m['opens'] as String?,
    );
  }

  /// مرتبة حسب البداية في السنة الميلادية.
  final List<TradSeason> seasons;
  final String approval;

  /// الموسم الذي يقع فيه [day] (التاريخ فقط)، والتالي والأيام المتبقية له.
  CurrentTradSeason on(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    // آخر بداية ≤ d: نبحث في هذه السنة ثم السابقة (الالتفاف عبر السنة).
    var index = -1;
    var start = d;
    for (var i = seasons.length - 1; i >= 0; i--) {
      final s = DateTime(d.year, seasons[i].startMonth, seasons[i].startDay);
      if (!s.isAfter(d)) {
        index = i;
        start = s;
        break;
      }
    }
    if (index < 0) {
      index = seasons.length - 1;
      final last = seasons[index];
      start = DateTime(d.year - 1, last.startMonth, last.startDay);
    }
    final nextIndex = (index + 1) % seasons.length;
    final next = seasons[nextIndex];
    final nextYear = nextIndex == 0 ? start.year + 1 : start.year;
    final nextStart = DateTime(nextYear, next.startMonth, next.startDay);
    return CurrentTradSeason(
      season: seasons[index],
      next: next,
      start: start,
      end: DateTime(nextStart.year, nextStart.month, nextStart.day - 1),
      daysRemaining: daysBetween(d, nextStart),
      approval: approval,
    );
  }
}

/// سطر الوصف تحت اسم الموسم: يبدأ باسم الموسم (طلب المالك)، مثل «الوسم يُترقّب فيه المطر…».
String tradDescriptionLine(String name, String description) =>
    description.isEmpty || description.startsWith(name) ? description : '$name $description';
