class IcsEvent {
  final String uid, title;
  final DateTime date; // يوم كامل
  const IcsEvent(this.uid, this.title, this.date);
}

String _d(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

String _esc(String s) => s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll(';', '\\;').replaceAll('\n', '\\n');

/// ملف تقويم (.ics) بأحداث يوم كامل.
String buildIcs(List<IcsEvent> evs, {DateTime? stamp}) {
  final s = stamp ?? DateTime.now().toUtc();
  final st = '${_d(s)}T${s.hour.toString().padLeft(2, '0')}${s.minute.toString().padLeft(2, '0')}${s.second.toString().padLeft(2, '0')}Z';
  final b = StringBuffer('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//mawid//AR\r\nCALSCALE:GREGORIAN\r\n');
  for (final e in evs) {
    b.write('BEGIN:VEVENT\r\nUID:${e.uid}@mawid\r\nDTSTAMP:$st\r\n'
        'DTSTART;VALUE=DATE:${_d(e.date)}\r\n'
        'DTEND;VALUE=DATE:${_d(e.date.add(const Duration(days: 1)))}\r\n'
        'SUMMARY:${_esc(e.title)}\r\nEND:VEVENT\r\n');
  }
  b.write('END:VCALENDAR\r\n');
  return b.toString();
}
