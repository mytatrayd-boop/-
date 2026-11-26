import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_failure.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/ports/auth_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../login/auth_status_provider.dart';
import '../login/login_screen.dart';
import '../player/failure_message.dart';
import 'locale_controller.dart';

/// إعدادات بسيطة بما هو متاح الآن: الحساب واللغة وحول. (الحصة وتحسين البطارية
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
            const _AccountSection(),
            const Divider(),
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

/// قسم الحساب: الحالة + الدخول أو الخروج (بتأكيد).
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  bool _busy = false;

  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('signOutDialog'),
        title: Text(l.signOutConfirmTitle),
        content: Text(l.signOutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l.cancel)),
          FilledButton(
            key: const Key('signOutConfirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } on AppFailure catch (f) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failureMessage(l, f))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(authStatusProvider);
    final (subtitle, color) = switch (status) {
      AuthStatus.signedIn => (l.accountSignedIn, AppColors.success),
      AuthStatus.signedOut => (l.accountSignedOut, AppColors.textSecondary),
      AuthStatus.expired => (l.sessionExpired, AppColors.warning),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SettingsScreen.rowHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.accountTitle, style: theme.textTheme.titleMedium),
                  Text(subtitle, key: const Key('accountStatus'), style: TextStyle(color: color)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (status == AuthStatus.signedIn)
              OutlinedButton(
                key: const Key('accountSignOut'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _busy ? null : _signOut,
                child: Text(l.signOut),
              )
            else
              FilledButton(
                key: const Key('accountSignIn'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _busy ? null : () => openLoginScreen(context),
                child: Text(l.signIn),
              ),
          ],
        ),
      ),
    );
  }
}
