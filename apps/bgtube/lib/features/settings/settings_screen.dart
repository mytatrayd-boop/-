import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'locale_controller.dart';

/// إعدادات بسيطة بما هو متاح الآن: اللغة وحول. (الحساب والحصة وتحسين البطارية
/// تأتي مع ميزاتها.)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const rowHeight = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = Localizations.localeOf(context).languageCode;
    final version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: rowHeight),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.settingsLanguage, style: Theme.of(context).textTheme.titleMedium),
                    Text(l.settingsLanguageHint, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      key: const Key('languageSelector'),
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
                      segments: [
                        ButtonSegment(value: 'ar', label: Text(l.languageArabic)),
                        ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
                      ],
                      selected: {current},
                      onSelectionChanged: (s) =>
                          ref.read(localeProvider.notifier).setLanguage(s.single),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: rowHeight),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.settingsAbout, style: Theme.of(context).textTheme.titleMedium),
                    if (version.isNotEmpty)
                      Text(l.settingsVersion(version),
                          style: const TextStyle(color: AppColors.textSecondary)),
                    Text(l.settingsPersonalUse,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
