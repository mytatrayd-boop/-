import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../formatting/date_labels.dart';
import '../../hijri/hijri_date.dart';
import '../../routing/app_router.dart';
import 'city_chip.dart';

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
      appBar: AppBar(
        // DESIGN 8.4: شريحة المدينة في البداية (يمين)، والإعدادات في النهاية.
        title: const CityChip(),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
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
