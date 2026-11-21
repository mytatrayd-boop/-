import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

// ------------------------------------------------------------------ violations (owner)

/// The owner takes points from one member or from everyone. Each violation in
/// the list can be deleted, which gives its points back.
class ViolationsPage extends ConsumerStatefulWidget {
  const ViolationsPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<ViolationsPage> createState() => _ViolationsPageState();
}

class _ViolationsPageState extends ConsumerState<ViolationsPage> {
  var _to = 'all';
  final _pts = TextEditingController(text: '5'), _reason = TextEditingController();

  @override
  void dispose() {
    _pts.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    if (_to != 'all' && !d.members.any((m) => m.id == _to)) _to = 'all';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileViolations),
      Muted(t.violationsIntro),
      FormBox(children: [
        Select<String>(
          value: _to,
          label: t.to,
          items: [('all', t.allMembers), for (final m in d.members) (m.id, m.name)],
          onChanged: (v) => setState(() => _to = v),
        ),
        Labeled(t.violationPoints, TextField(controller: _pts, keyboardType: TextInputType.number)),
        TextField(controller: _reason, maxLength: 120, decoration: InputDecoration(hintText: t.violationReasonHint, counterText: '')),
        Btn(t.addViolation, kind: BtnKind.no, onPressed: () async {
          final pts = int.tryParse(_pts.text.trim()) ?? 0;
          if (pts < 1 || pts > 1000) return toast(context, t.errViolationPoints);
          final ok = await run(context, () => ref.read(backendProvider).addViolation(personId: _to, points: pts, reason: _reason.text.trim()),
              ok: t.violationAdded);
          if (ok) _reason.clear();
        }),
      ]),
      H3(t.violationsList),
      if (d.violations.isEmpty) EmptyState('✅', t.noViolations),
      for (final v in d.violations)
        OutlineCard(
          child: Row(children: [
            const Text('😞', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.all ? t.allMembers : v.personIds.map((id) => d.person(id)?.name ?? '—').join('، '),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (v.reason.isNotEmpty) Muted(v.reason),
                Muted(ago(t, v.at, now)),
              ]),
            ),
            Text('−${v.points}', style: const TextStyle(color: Palette.red, fontWeight: FontWeight.w800, fontSize: 18)),
            XButton(
              tooltip: t.deleteViolation,
              icon: Icons.delete_outline,
              onPressed: () async {
                if (!await confirm(context, t.deleteViolationQ, ok: t.delete)) return;
                if (context.mounted) await run(context, () => ref.read(backendProvider).deleteViolation(v.id), ok: t.violationDeleted);
              },
            ),
          ]),
        ),
    ]);
  }
}

// ------------------------------------------------------------------ evaluation cycle (owner)

/// "Start a new evaluation cycle": two warnings, then every point is wiped.
class CyclePage extends ConsumerWidget {
  const CyclePage(this.c, {super.key});
  final Ctx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t, started = c.data.cycleStartedAt;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileCycle),
      FormBox(children: [
        Text(started == null ? t.cycleNever : t.cycleSince(arabicDay(started)), style: const TextStyle(fontWeight: FontWeight.w700)),
        Muted(t.cycleIntro),
        Btn(t.startCycle, kind: BtnKind.no, onPressed: () async {
          if (!await confirm(context, t.cycleWarn1, ok: t.next, danger: true) || !context.mounted) return;
          if (!await confirmCycle(context) || !context.mounted) return;
          await run(context, () => ref.read(backendProvider).newCycle(), ok: t.cycleStarted);
        }),
      ]),
    ]);
  }
}

/// Second warning, worded as the owner asked: إلغاء / تأكيد.
Future<bool> confirmCycle(BuildContext context) async {
  final t = context.t;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t.cycleWarn2Title),
      content: Text('${t.cycleWarn2}\n\n${t.cycleAsk}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t.confirmWord, style: const TextStyle(color: Palette.red, fontWeight: FontWeight.w700))),
      ],
    ),
  );
  return r ?? false;
}

String arabicDay(DateTime d) {
  final r = d.toUtc().add(const Duration(hours: 3));
  return '${r.day}/${r.month}/${r.year}';
}

// ------------------------------------------------------------------ the member's pop-up

/// Round, pulsing violation card: a sad face, the word «مخالفة» with a bell,
/// the member's name, then the points taken in gold crossed by a red ✕.
class ViolationCard extends StatefulWidget {
  const ViolationCard({super.key, required this.name, required this.points, this.reason = '', this.size = 230});
  final String name;
  final int points;
  final String reason;
  final double size;
  @override
  State<ViolationCard> createState() => _ViolationCardState();
}

class _ViolationCardState extends State<ViolationCard> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, s = widget.size;
    final circle = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.pal.card,
        border: Border.all(color: Palette.red, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x55C8424A), blurRadius: 22, spreadRadius: 2)],
      ),
      padding: EdgeInsets.all(s * .09),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('😞', style: TextStyle(fontSize: s * .2)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_active_rounded, color: Palette.red, size: s * .1),
          const SizedBox(width: 4),
          Text(t.violationWord, style: TextStyle(fontFamily: headFont, fontWeight: FontWeight.w800, fontSize: s * .1, color: Palette.red)),
        ]),
        Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: s * .075)),
        SizedBox(height: s * .02),
        Stack(alignment: Alignment.center, children: [
          Text('${widget.points}', style: TextStyle(fontFamily: headFont, fontWeight: FontWeight.w800, fontSize: s * .16, color: Palette.sunDeep)),
          Text('✕', style: TextStyle(fontSize: s * .2, color: Palette.red.withValues(alpha: .85), fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
    return ScaleTransition(
      scale: Tween(begin: .94, end: 1.04).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: circle,
    );
  }
}

/// Shows unread violations one after another as a pop-up; closing marks them read.
Future<void> showViolationPopup(BuildContext context, List<Notice> ns, String name) async {
  final t = context.t;
  for (final n in ns) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ViolationCard(name: name, points: n.points),
          if (n.body.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(14)),
              child: Text(n.body, textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 14),
          Btn(t.ok, onPressed: () => Navigator.pop(c)),
        ]),
      ),
    );
  }
}
