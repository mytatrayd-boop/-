import 'geo_point.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// يمنع محارف التحكم غير المسموحة في XML 1.0.
String _clean(String s) =>
    s.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]'), '');

String _num(double v) {
  final s = v.toStringAsFixed(6);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// يولّد GPX 1.1 نصياً. النقاط غير الصالحة تُتجاهل. مسار فارغ يعطي ملفاً
/// صحيحاً بلا trkpt. الأوقات تُكتب UTC بصيغة ISO-8601.
String buildGpx(
  List<GeoPoint> points, {
  String name = 'Rihla',
  DateTime? time,
}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="Rihla" '
      'xmlns="http://www.topografix.com/GPX/1/1">',
    );
  if (time != null) {
    b
      ..writeln('  <metadata>')
      ..writeln('    <time>${time.toUtc().toIso8601String()}</time>')
      ..writeln('  </metadata>');
  }
  b
    ..writeln('  <trk>')
    ..writeln('    <name>${_esc(_clean(name))}</name>')
    ..writeln('    <trkseg>');
  for (final p in points.where((p) => p.isValid)) {
    b.write('      <trkpt lat="${_num(p.lat)}" lon="${_num(p.lng)}">');
    if (p.elevation != null && p.elevation!.isFinite) {
      b.write('<ele>${_num(p.elevation!)}</ele>');
    }
    if (p.time != null) {
      b.write('<time>${p.time!.toUtc().toIso8601String()}</time>');
    }
    b.writeln('</trkpt>');
  }
  b
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return b.toString();
}
