import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backend/backend.dart';
import '../core/logic.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'sheets.dart';
import 'theme.dart';

/// Page frame: green header with the family's portraits, a panel overlapping
/// it, and (signed in) the bottom bar: home, reports, prizes, settings.
class Shell extends ConsumerWidget {
  const Shell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appStateProvider).value ?? const AppState();
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 24 + (st.signedIn ? 0 : MediaQuery.paddingOf(context).bottom)),
        child: Column(children: [
          _Header(st: st),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.pal.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Palette.sun.withValues(alpha: .35)),
                      boxShadow: const [BoxShadow(color: Color(0x1A1E3C32), blurRadius: 24, offset: Offset(0, 6))],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: st.signedIn ? _NavBar(me: st.me!) : null,
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.me});
  final Person me;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final reports = me.role == Role.member || can(me, Perm.viewReports) || can(me, Perm.report);
    final items = [
      ('/', Icons.home_outlined, Icons.home_rounded, t.navHome),
      if (reports) ('/report', Icons.insert_chart_outlined, Icons.insert_chart_rounded, t.navReports),
      ('/prizes', Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, t.navPrizes),
      ('/settings', Icons.settings_outlined, Icons.settings_rounded, t.settings),
    ];
    final path = GoRouterState.of(context).uri.path;
    final i = items.indexWhere((x) => x.$1 == path);
    return NavigationBar(
      height: 64,
      backgroundColor: context.pal.card,
      indicatorColor: context.pal.mintBg,
      // Inner admin pages belong to the home tab.
      selectedIndex: i < 0 ? 0 : i,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (n) => context.go(items[n].$1),
      destinations: [
        for (final (_, icon, sel, label) in items)
          NavigationDestination(icon: Icon(icon, color: context.pal.muted), selectedIcon: Icon(sel, color: Palette.brand), label: label),
      ],
    );
  }
}

/// Round header button (feedback, demo mailbox).
class _HeadIcon extends StatelessWidget {
  const _HeadIcon(this.icon, this.tip, this.onTap, {this.dot = false});
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool dot;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: Semantics(
          button: true,
          label: tip,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Stack(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              if (dot) const PositionedDirectional(top: 6, end: 6, child: CircleAvatar(radius: 4, backgroundColor: Palette.sun)),
            ]),
          ),
        ),
      );
}

/// Pill in the header's bottom row (the signed-in name, sign-out): same height and style.
class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.onTap, required this.label});
  final Widget child;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: const Color(0xF2FFFFFF),
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(height: 42, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: child)),
          ),
        ),
      );
}

class _Header extends ConsumerWidget {
  const _Header({required this.st});
  final AppState st;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final backend = ref.watch(backendProvider);
    final me = st.signedIn ? st.me : null;
    final data = st.data;
    const ink = Color(0xFF1E302C);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14 + MediaQuery.paddingOf(context).top, 16, 50),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2F6158), Color(0xFF244D46)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.white,
                  width: 44,
                  height: 44,
                  child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover, excludeFromSemantics: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.appName,
                      style: const TextStyle(
                          fontFamily: headFont, fontSize: 24, height: 1.1, color: Colors.white, fontVariations: [FontVariation('wght', 800)])),
                  Text(me != null && data != null ? data.familyName : t.tagline,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE9D6A6), fontSize: 13)),
                ]),
              ),
              _HeadIcon(Icons.chat_bubble_outline_rounded, t.feedback, () => openSheet(context, (_) => const FeedbackSheet())),
              if (backend.isDemo) ...[
                const SizedBox(width: 8),
                _HeadIcon(Icons.mail_outline_rounded, t.demoMailbox, () => showMailbox(context, backend.outbox), dot: backend.outbox.isNotEmpty),
              ],
            ]),
            if (me != null && data != null) ...[
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, box) {
                // Five portraits to a line.
                final size = ((box.maxWidth - 4 * 10) / 5).clamp(40.0, 64.0);
                return Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final p in data.people)
                      NameRing(
                        person: p,
                        size: size,
                        onTap: canEditAvatar(me, p) ? () => showAvatarPicker(context, ref, p) : null,
                      ),
                  ],
                );
              }),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _Pill(
                      label: '${t.changeMyAvatar}: ${me.name}',
                      onTap: () => showAvatarPicker(context, ref, me),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        AvatarView.of(me, size: 26),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: me.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: ' · ${roleLabel(t, me.role)}'),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: ink, fontSize: 13),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sign-out in plain sight next to the signed-in name (testers could not find it in the settings).
                _Pill(
                  label: t.signOut,
                  onTap: () async {
                    final router = GoRouter.of(context);
                    if (!await confirm(context, t.signOutConfirm, ok: t.signOut)) return;
                    await ref.read(backendProvider.notifier).signOut();
                    router.go('/');
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.logout_rounded, size: 18, color: Palette.brand),
                    const SizedBox(width: 6),
                    Text(t.signOut, style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
              if (backend.isDemo) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('🧪 ${t.demoBanner}', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
                ),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

/// Current signed-in context for pages.
class Ctx {
  Ctx(this.state) : data = state.data!, me = state.me!;
  final AppState state;
  final FamilySnapshot data;
  final Person me;
}

/// "‹ title" link back to the home page, at the top of inner pages.
class BackLink extends StatelessWidget {
  const BackLink(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), foregroundColor: context.pal.brandInk),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}
