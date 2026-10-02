import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../hijri/hijri_date.dart';

/// شاشة مؤقتة لهيكل المشروع. الدائرة التفاعلية تأتي في الميزة 6.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.today});

  /// للاختبارات فقط؛ في التشغيل العادي يُستخدم تاريخ الجهاز.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = today ?? DateTime.now();
    final hijri = HijriDate.fromGregorian(now);
    final number = NumberFormat('#', locale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.todayLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.hijriDate(
                number.format(hijri.day),
                'm${hijri.month}',
                number.format(hijri.year),
              ),
              key: const Key('hijriDate'),
            ),
            Text(
              DateFormat.yMMMMd(locale).format(now),
              key: const Key('gregorianDate'),
            ),
            const Spacer(),
            Text(l10n.traditionDisclaimer),
          ],
        ),
      ),
    );
  }
}
