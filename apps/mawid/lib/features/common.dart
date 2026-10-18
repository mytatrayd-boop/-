import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../model/programs.dart';

String hijriText(DateTime d) {
  HijriCalendar.setLocal('ar'); // أسماء الأشهر بالعربية
  final h = HijriCalendar.fromDate(d);
  return '${h.hDay} ${h.getLongMonthName()} ${h.hYear} هـ';
}

String dateText(DateTime d) =>
    '${weekdayAr[d.weekday]} ${d.day} ${monthAr[d.month - 1]} ${d.year}';

class Pill extends StatelessWidget {
  final String text;
  const Pill(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: warnBg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(color: warnFg, fontWeight: FontWeight.w700)),
      );
}

class Card1 extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const Card1({super.key, required this.child, this.margin = const EdgeInsets.fromLTRB(14, 0, 14, 12)});
  @override
  Widget build(BuildContext c) => Padding(
        padding: margin,
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: line),
          ),
          child: SizedBox(width: double.infinity, child: Padding(padding: const EdgeInsets.all(16), child: child)),
        ),
      );
}

TextStyle get h2 => TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink);

/// Opens an official source in the browser.
Future<void> openSource(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر فتح $url')));
  }
}

/// "المصدر الرسمي: …" with a link, shown wherever a date is shown in detail.
class SourceLink extends StatelessWidget {
  final String label, url;
  const SourceLink(this.label, this.url, {super.key});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.open_in_new, size: 20),
        title: Text(label),
        subtitle: Text(url.replaceFirst('https://', ''), textDirection: TextDirection.ltr, textAlign: TextAlign.right),
        onTap: () => openSource(context, url),
      );
}
