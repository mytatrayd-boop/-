import 'dart:convert';

import 'arabic.dart';

/// مواعيد الإيداعات (SPEC §4، DECISIONS ١ و٢). القواعد والاستثناءات كلها من
/// `assets/deposits.json`؛ لا مواعيد مكتوبة في الكود.

const _weekdayKeys = {
  'monday': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'friday': DateTime.friday,
  'saturday': DateTime.saturday,
  'sunday': DateTime.sunday,
};

class DepositRule {
  const DepositRule({
    required this.id,
    required this.name,
    required this.day,
    required this.weekendShift,
    this.monthLabel,
    this.defaultEnabled = true,
  });

  factory DepositRule.fromJson(Map<String, dynamic> j) {
    final rule = (j['weekendRule'] as Map<String, dynamic>?) ?? const {};
    final shift = <int, int>{};
    rule.forEach((k, v) {
      final wd = _weekdayKeys[k];
      if (wd == null) {
        throw FormatException('deposits.json: يوم غير معروف "$k" في weekendRule.');
      }
      shift[wd] = v as int;
    });
    final day = j['day'] as int;
    if (day < 1 || day > 28) {
      throw FormatException('deposits.json: اليوم $day خارج 1..28.');
    }
    return DepositRule(
      id: j['id'] as String,
      name: j['name'] as String,
      day: day,
      weekendShift: shift,
      monthLabel: j['monthLabel'] as String?,
      defaultEnabled: (j['defaultEnabled'] as bool?) ?? true,
    );
  }

  final String id;

  /// الاسم العربي (مثل «الرواتب»).
  final String name;

  /// اليوم الميلادي من الشهر.
  final int day;

  /// إزاحة الموعد بالأيام حسب يوم الأسبوع (`DateTime.weekday`).
  final Map<int, int> weekendShift;

  /// إن وُجد يُعرض مع اسم الشهر («راتب أكتوبر»)، وإلا يُعرض [name] وحده.
  final String? monthLabel;

  /// مفعّل في الإعدادات الافتراضية (الحقل `defaultEnabled`، الافتراضي true).
  final bool defaultEnabled;
}

class DepositException {
  const DepositException(this.id, this.year, this.month, this.date);

  final String id;

  /// شهر الاستحقاق.
  final int year;
  final int month;

  /// الموعد الفعلي الذي يتجاوز الحساب.
  final DateTime date;
}

/// موعد إيداع محدد.
class DepositOccurrence {
  const DepositOccurrence({
    required this.id,
    required this.name,
    required this.label,
    required this.date,
    required this.dueYear,
    required this.dueMonth,
    required this.daysRemaining,
  });

  final String id;
  final String name;

  /// الاسم مع الشهر («راتب أكتوبر») أو الاسم وحده لغير الراتب.
  final String label;

  /// يوم الإيداع الفعلي (التاريخ فقط).
  final DateTime date;

  /// شهر الاستحقاق (قبل إزاحة العطلة).
  final int dueYear;
  final int dueMonth;

  final int daysRemaining;

  /// «اليوم» أو «باقي ٣ أيام».
  String get remainingText => remainingDaysText(daysRemaining);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'label': label,
        'date': isoDate(date),
        'daysRemaining': daysRemaining,
        'remainingText': remainingText,
        'afterText': afterDaysText(daysRemaining),
        'daysText': daysCountText(daysRemaining),
      };
}

class DepositsConfig {
  DepositsConfig(this.rules, this.exceptions);

  factory DepositsConfig.fromJsonString(String source) =>
      DepositsConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory DepositsConfig.fromJson(Map<String, dynamic> j) {
    final rules = [
      for (final r in j['deposits'] as List)
        DepositRule.fromJson(r as Map<String, dynamic>),
    ];
    final ids = rules.map((r) => r.id).toSet();
    final exceptions = <DepositException>[];
    for (final e in (j['exceptions'] as List?) ?? const []) {
      final m = e as Map<String, dynamic>;
      final id = m['id'] as String;
      if (!ids.contains(id)) {
        throw FormatException('deposits.json: استثناء لإيداع غير معروف "$id".');
      }
      final month = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(m['month'] as String);
      final date = DateTime.tryParse(m['date'] as String);
      if (month == null || date == null) {
        throw FormatException('deposits.json: استثناء غير صالح $m.');
      }
      exceptions.add(DepositException(id, int.parse(month[1]!),
          int.parse(month[2]!), DateTime(date.year, date.month, date.day)));
    }
    return DepositsConfig(rules, exceptions);
  }

  final List<DepositRule> rules;
  final List<DepositException> exceptions;

  Set<String> get ids => {for (final r in rules) r.id};

  /// الإيداعات المفعّلة افتراضياً لمستخدم جديد.
  Set<String> get defaultIds => {
        for (final r in rules)
          if (r.defaultEnabled) r.id,
      };

  DepositRule rule(String id) => rules.firstWhere((r) => r.id == id,
      orElse: () => throw ArgumentError.value(id, 'id', 'إيداع غير معروف'));

  /// الموعد الفعلي لإيداع [id] المستحق في [year]/[month].
  DateTime dateFor(String id, int year, int month) {
    for (final e in exceptions) {
      if (e.id == id && e.year == year && e.month == month) return e.date;
    }
    final r = rule(id);
    final base = DateTime(year, month, r.day);
    final shift = r.weekendShift[base.weekday] ?? 0;
    return DateTime(year, month, r.day + shift);
  }

  DepositOccurrence _occurrence(DepositRule r, int year, int month, DateTime today) {
    final date = dateFor(r.id, year, month);
    final label = r.monthLabel == null
        ? r.name
        : '${r.monthLabel} ${gregorianMonthNames[month - 1]}';
    return DepositOccurrence(
      id: r.id,
      name: r.name,
      label: label,
      date: date,
      dueYear: year,
      dueMonth: month,
      daysRemaining: daysBetween(today, date),
    );
  }

  /// أقرب موعد قادم (أو اليوم) لكل إيداع في [enabled]، مرتبة الأقرب فالأقرب،
  /// وبحد أقصى [count]. يُؤخذ التاريخ فقط من [today].
  List<DepositOccurrence> nextDeposits(
    DateTime today,
    Set<String> enabled, {
    int count = 2,
  }) {
    if (enabled.isEmpty) {
      throw ArgumentError.value(enabled, 'enabled', 'يلزم إيداع واحد على الأقل');
    }
    final day = DateTime(today.year, today.month, today.day);
    final result = <DepositOccurrence>[];
    for (final r in rules) {
      if (!enabled.contains(r.id)) continue;
      // من الشهر السابق: إزاحة العطلة أو الاستثناء قد تنقل الموعد لشهر آخر.
      for (var k = -1; k <= 13; k++) {
        final m = DateTime(day.year, day.month + k);
        final occ = _occurrence(r, m.year, m.month, day);
        if (occ.daysRemaining >= 0) {
          result.add(occ);
          break;
        }
      }
    }
    for (final id in enabled) {
      rule(id); // يرمي لمعرّف غير معروف.
    }
    int order(String id) => rules.indexWhere((r) => r.id == id);
    result.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : order(a.id).compareTo(order(b.id));
    });
    return result.take(count).toList();
  }
}
