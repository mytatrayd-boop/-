/// يوم وشهر يتكرران كل سنة، بصيغة "MM-DD" في الجداول.
///
/// 29 فبراير غير مسموح في الجداول؛ يُعامل حسب قاعدة المنطقة (D7).
class MonthDay implements Comparable<MonthDay> {
  const MonthDay(this.month, this.day);

  factory MonthDay.parse(String value, String where) {
    final match = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('$where: التاريخ "$value" ليس بصيغة MM-DD.');
    }
    final md = MonthDay(int.parse(match[1]!), int.parse(match[2]!));
    if (md.month < 1 ||
        md.month > 12 ||
        md.day < 1 ||
        md.day > _daysInCommonYear[md.month - 1]) {
      throw FormatException('$where: التاريخ "$value" غير صالح '
          '(29 فبراير غير مسموح في الجداول).');
    }
    return md;
  }

  factory MonthDay.of(DateTime date) => MonthDay(date.month, date.day);

  static const _daysInCommonYear = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  final int month;
  final int day;

  bool get isFeb29 => month == 2 && day == 29;

  int get _ordinal => month * 100 + day;

  /// التاريخ في سنة معيّنة (UTC لتجنب مشاكل التوقيت الصيفي).
  DateTime inYear(int year) => DateTime.utc(year, month, day);

  @override
  int compareTo(MonthDay other) => _ordinal.compareTo(other._ordinal);

  bool operator <=(MonthDay other) => _ordinal <= other._ordinal;
  bool operator <(MonthDay other) => _ordinal < other._ordinal;

  @override
  bool operator ==(Object other) =>
      other is MonthDay && other.month == month && other.day == day;

  @override
  int get hashCode => _ordinal;

  @override
  String toString() =>
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
