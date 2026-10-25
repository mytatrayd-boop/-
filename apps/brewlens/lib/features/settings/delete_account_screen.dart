import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/data_providers.dart';
import '../../app/failure_text.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../l10n/app_localizations.dart';

/// صفحة إدارة الاشتراكات في متجر المنصة.
Uri _storeSubscriptions(BuildContext context) => Theme.of(context).platform == TargetPlatform.iOS
    ? Uri.parse('https://apps.apple.com/account/subscriptions')
    : Uri.parse('https://play.google.com/store/account/subscriptions');

/// حذف الحساب بتأكيد صريح: كتابة «حذف» / DELETE (F10 معيار 3، DESIGN §3.9).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      ref.read(pendingAnalysisProvider.notifier).set(null);
      await ref.read(accountRepositoryProvider).deleteAccount();
      refreshCollectionsFromWidget(ref);
      // الجلسة انتهت؛ redirect ينقل للدخول.
      rootNavigatorKey.currentContext?.go(Routes.login);
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final matches = _confirm.text.trim().toUpperCase() == l.deleteConfirmWord.toUpperCase();
    return PopScope(
      canPop: !_busy,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(title: Text(l.deleteAccount)),
            body: ListView(
              padding: const EdgeInsetsDirectional.all(16),
              children: [
                Icon(Icons.warning_amber_rounded, size: 64, color: scheme.error),
                const SizedBox(height: 16),
                Text(l.deleteAccountWarning, style: text.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsetsDirectional.all(12),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.deleteAccountSubscriptionNote,
                          style: text.bodyMedium?.copyWith(color: scheme.onSecondaryContainer)),
                      TextButton(
                        onPressed: () => launchUrl(_storeSubscriptions(context),
                            mode: LaunchMode.externalApplication),
                        child: Text(l.manageSubscription),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('delete_confirm_field'),
                  controller: _confirm,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: l.deleteConfirmLabel(l.deleteConfirmWord)),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('delete_account_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: matches && !_busy ? _delete : null,
                  child: Text(l.deleteAccountButton),
                ),
              ],
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Color(0x66000000)),
            ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
