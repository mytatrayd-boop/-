import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/data_providers.dart';
import '../../app/legal_links.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../legal/legal_screen.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// خلفية مفتاح وضع العرض (DESIGN §3.9).
const _demoTint = Color(0x33FFE08A);

/// الإعدادات (F10، DESIGN §3.9).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _pickLanguage() async {
    final l = AppLocalizations.of(context);
    final current = ref.read(localeProvider)?.languageCode ?? '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(context).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(key: const Key('lang_system'), value: '', title: Text(l.languageSystem)),
              RadioListTile(key: const Key('lang_ar'), value: 'ar', title: Text(l.languageArabic)),
              RadioListTile(key: const Key('lang_en'), value: 'en', title: Text(l.languageEnglish)),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(localeProvider.notifier).set(picked.isEmpty ? null : Locale(picked));
  }

  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.signOutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(
            key: const Key('confirm_sign_out'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.signOut),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    ref.read(pendingAnalysisProvider.notifier).set(null);
    // تغيّر الجلسة يعيد للدخول عبر redirect.
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _toggleSubscriber(bool value) async {
    await ref.read(subscriberSimulatorProvider)!.setSimulateSubscriber(value);
    ref.invalidate(usageProvider);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider);
    final usage = ref.watch(usageProvider).value;
    final simulator = ref.watch(subscriberSimulatorProvider);
    final locale = ref.watch(localeProvider);
    final languageValue = switch (locale?.languageCode) {
      'ar' => l.languageArabic,
      'en' => l.languageEnglish,
      _ => l.languageSystem,
    };
    final subscribed = usage?.isSubscriber ?? false;

    Widget header(String title) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 8),
          child: Text(title, style: text.titleSmall?.copyWith(color: scheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        children: [
          header(l.settingsAccount),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(l.emailLabel),
            subtitle: Text(session?.email ?? '', textDirection: TextDirection.ltr),
          ),
          ListTile(
            key: const Key('settings_subscription'),
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(l.subscription),
            trailing: Text(subscribed ? l.subscriptionActive : l.subscriptionFree),
            onTap: subscribed ? null : () => context.push(Routes.paywallFromSettings),
          ),
          header(l.settingsApp),
          ListTile(
            key: const Key('settings_language'),
            leading: const Icon(Icons.language),
            title: Text(l.language),
            trailing: Text(languageValue),
            onTap: _pickLanguage,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.privacyPolicy),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => openLegal(context, LegalDoc.privacy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.termsOfUse),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => openLegal(context, LegalDoc.terms),
          ),
          if (simulator != null) ...[
            header(l.settingsDemo),
            SwitchListTile(
                tileColor: _demoTint,
                key: const Key('simulate_subscriber'),
                secondary: const Icon(Icons.science_outlined),
                title: Text(l.simulateSubscriber),
                subtitle: Text(l.simulateSubscriberHint),
                value: simulator.simulateSubscriber,
                onChanged: _toggleSubscriber,
              ),
          ],
          const SizedBox(height: 24),
          ListTile(
            key: const Key('settings_sign_out'),
            leading: Icon(Icons.logout, color: scheme.primary),
            title: Text(l.signOut, style: TextStyle(color: scheme.primary)),
            onTap: _signOut,
          ),
          ListTile(
            key: const Key('settings_delete_account'),
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text(l.deleteAccount, style: TextStyle(color: scheme.error)),
            onTap: () => context.push(Routes.deleteAccount),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Text(
              l.versionLabel(ref.watch(appVersionProvider).value ?? ''),
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
