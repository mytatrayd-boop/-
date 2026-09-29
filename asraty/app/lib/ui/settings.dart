import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

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

    Future<void> signOut() async {
      context.go('/');
      await notifier.signOut();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), foregroundColor: context.pal.brandInk),
          child: Text(t.back, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      H2(t.settings),
      H3(t.appearance),
      SegTabs<ThemeMode>(
        tabs: [(ThemeMode.system, t.themeSystem, 0), (ThemeMode.light, t.themeLight, 0), (ThemeMode.dark, t.themeDark, 0)],
        value: mode,
        onChanged: ref.read(themeModeProvider.notifier).set,
      ),
      if (AppConfig.privacyUrl.isNotEmpty) ...[
        RowCard(children: [
          Expanded(child: Text(t.privacyPolicy, style: const TextStyle(fontWeight: FontWeight.w700))),
          SelectableText(AppConfig.privacyUrl, textDirection: TextDirection.ltr, style: TextStyle(color: context.pal.muted, fontSize: 13)),
        ]),
      ],
      const SizedBox(height: 8),
      Btn(t.signOut, kind: BtnKind.ghost, expand: true, onPressed: signOut),
      H3(t.dangerZone),
      if (isOwner)
        Btn(t.deleteFamily, kind: BtnKind.no, expand: true, onPressed: () async {
          if (!await confirm(context, t.deleteFamilyConfirm, ok: t.deleteConfirmBtn, danger: true) || !context.mounted) return;
          final b = ref.read(backendProvider);
          final ok = await run(context, b.deleteFamily, ok: t.deleted);
          if (ok && context.mounted) await signOut();
        })
      else
        Btn(t.deleteMyAccount, kind: BtnKind.no, expand: true, onPressed: () async {
          if (!await confirm(context, t.deleteAccountConfirm, ok: t.deleteConfirmBtn, danger: true) || !context.mounted) return;
          final b = ref.read(backendProvider);
          final ok = await run(context, b.deleteAccount, ok: t.deleted);
          if (ok && context.mounted) await signOut();
        }),
      const SizedBox(height: 16),
      Center(child: Muted(t.version(const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')))),
    ]);
  }
}
