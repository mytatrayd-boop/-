import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backend/backend.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'sheets.dart';
import 'theme.dart';

/// Page frame from the prototype: green header with the family rings, and a
/// white panel overlapping it.
class Shell extends ConsumerWidget {
  const Shell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appStateProvider).value ?? const AppState();
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        child: Column(children: [
          _Header(st: st),
          Transform.translate(
            offset: const Offset(0, -38),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.pal.card,
                      borderRadius: BorderRadius.circular(20),
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
    );
  }
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
    Widget hb(String label, String tip, VoidCallback onTap, {bool dot = false}) => Tooltip(
          message: tip,
          child: Semantics(
            button: true,
            label: tip,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Stack(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(10)),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ),
                if (dot)
                  const PositionedDirectional(
                    top: 5,
                    end: 5,
                    child: CircleAvatar(radius: 4, backgroundColor: Palette.sun),
                  ),
              ]),
            ),
          ),
        );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 16 + MediaQuery.paddingOf(context).top, 16, 54),
      decoration: const BoxDecoration(
        color: Palette.brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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
                  width: 46,
                  height: 46,
                  child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover, excludeFromSemantics: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.appName,
                      style: const TextStyle(
                          fontFamily: headFont, fontSize: 26, height: 1.1, color: Colors.white, fontVariations: [FontVariation('wght', 800)])),
                  Text(me != null && data != null ? data.familyName : t.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14)),
                ]),
              ),
              hb('💬', t.feedback, () => openSheet(context, (_) => const FeedbackSheet())),
              if (backend.isDemo) ...[
                const SizedBox(width: 6),
                hb('📧', t.demoMailbox, () => showMailbox(context, backend.outbox), dot: backend.outbox.isNotEmpty),
              ],
              if (me != null) ...[
                const SizedBox(width: 6),
                hb('⚙️', t.settings, () => context.push('/settings')),
              ],
            ]),
            if (me != null && data != null) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [for (final p in data.people) NameRing(person: p)],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  button: true,
                  label: t.changeMyAvatar,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => showAvatarPicker(context, ref, me),
                    child: Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
                      decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        AvatarView(me.avatar, size: 30),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('${me.name} · ${roleLabel(t, me.role)}',
                              overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 14, color: Colors.white),
                      ]),
                    ),
                  ),
                ),
              ),
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
