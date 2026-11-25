import 'package:intl/intl.dart';

/// m:ss أو h:mm:ss بأرقام اللغة (هندية في العربية إن كانت اللغة كذلك).
String formatDuration(Duration d, String locale) {
  final two = NumberFormat('00', locale);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${NumberFormat('0', locale).format(h)}:${two.format(m)}:${two.format(s)}';
  return '${NumberFormat('0', locale).format(m)}:${two.format(s)}';
}
