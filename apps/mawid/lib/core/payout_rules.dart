/// قاعدة الصرف: جمعة ← الخميس قبله، سبت ← الأحد بعده.
DateTime effectiveDate(int year, int month, int nominalDay) {
  final d = DateTime(year, month, nominalDay);
  if (d.weekday == DateTime.friday) return d.subtract(const Duration(days: 1));
  if (d.weekday == DateTime.saturday) return d.add(const Duration(days: 1));
  return d;
}

bool wasMoved(int year, int month, int nominalDay) =>
    effectiveDate(year, month, nominalDay) != DateTime(year, month, nominalDay);

/// أقرب موعد فعلي في اليوم [from] أو بعده (بدون وقت).
DateTime nextPayout(DateTime from, int nominalDay) {
  final today = DateTime(from.year, from.month, from.day);
  var e = effectiveDate(today.year, today.month, nominalDay);
  if (e.isBefore(today)) {
    final n = DateTime(today.year, today.month + 1, 1);
    e = effectiveDate(n.year, n.month, nominalDay);
  }
  return e;
}

int daysUntil(DateTime from, DateTime to) =>
    DateTime(to.year, to.month, to.day)
        .difference(DateTime(from.year, from.month, from.day))
        .inDays;

/// أقرب تاريخ سنوي (شهر/يوم) في اليوم [from] أو بعده.
DateTime nextAnnual(DateTime from, int month, int day) {
  final today = DateTime(from.year, from.month, from.day);
  var d = DateTime(today.year, month, day);
  if (d.isBefore(today)) d = DateTime(today.year + 1, month, day);
  return d;
}
