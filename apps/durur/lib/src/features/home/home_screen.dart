import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../formatting/date_labels.dart';
import '../../hijri/hijri_date.dart';

/// شاشة مؤقتة لهيكل المشروع. الدائرة التفاعلية تأتي في الميزة 6.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.today});

  /// للاختبارات فقط؛ في التشغيل العادي يُستخدم تاريخ الجهاز.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = today ?? DateTime.now();
    final hijri = HijriDate.fromGregorian(now);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.todayLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hijriDateLabel(l10n, hijri),
              key: const Key('hijriDate'),
            ),
            Text(
              gregorianDateLabel(l10n, now),
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
