import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';

/// Appearance, privacy policy, sign-out and in-app account / family deletion
/// (required by the App Store for apps with account creation).
class SettingsPage extends ConsumerWidget {
  const SettingsPage(this.c, {super.key});
  final Ctx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final mode = ref.watch(themeModeProvider);
    final isOwner = c.me.role == Role.owner;
    final notifier = ref.read(backendProvider.notifier);

    // Captured now: after a deletion the session can end (and this page unmount)
    // before the request returns, and the sign-out must still finish.
    final router = GoRouter.of(context);
    Future<void> signOut() async {
      await notifier.signOut();
      router.go('/');
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.settings),
      H3(t.appearance),
      SegTabs<ThemeMode>(
        tabs: [(ThemeMode.system, t.themeSystem, 0), (ThemeMode.light, t.themeLight, 0), (ThemeMode.dark, t.themeDark, 0)],
        value: mode,
        onChanged: ref.read(themeModeProvider.notifier).set,
      ),
      if (AppConfig.privacyUrl.isNotEmpty) ...[
        const SizedBox(height: 8),
        // One tappable line; the long URL itself is not shown.
        Btn('🔒 ${t.privacyPolicy}', kind: BtnKind.ghost, expand: true, onPressed: () async {
          final opened = await launchUrl(Uri.parse(AppConfig.privacyUrl), mode: LaunchMode.externalApplication).catchError((_) => false);
          if (!opened && context.mounted) toast(context, t.errNetwork);
        }),
      ],
      const SizedBox(height: 8),
      Btn(t.signOut, kind: BtnKind.ghost, expand: true, onPressed: signOut),
      H3(t.dangerZone),
      if (isOwner)
        Btn(t.deleteFamily, kind: BtnKind.no, expand: true, onPressed: () async {
          if (!await confirm(context, t.deleteFamilyConfirm, ok: t.deleteConfirmBtn, danger: true) || !context.mounted) return;
          final b = ref.read(backendProvider);
          final ok = await run(context, b.deleteFamily, ok: t.deleted);
          if (ok) await signOut();
        })
      else
        Btn(t.deleteMyAccount, kind: BtnKind.no, expand: true, onPressed: () async {
          if (!await confirm(context, t.deleteAccountConfirm, ok: t.deleteConfirmBtn, danger: true) || !context.mounted) return;
          final b = ref.read(backendProvider);
          final ok = await run(context, b.deleteAccount, ok: t.deleted);
          if (ok) await signOut();
        }),
      const SizedBox(height: 16),
      Center(child: Muted(t.version(const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.2')))),
    ]);
  }
}
