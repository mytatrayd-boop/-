import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'theme.dart';

/// Competition card (compCard in the prototype), for admins and members.
class CompCard extends ConsumerWidget {
  const CompCard({super.key, required this.comp, required this.data, this.admin = false, this.me});
  final Competition comp;
  final FamilySnapshot data;
  final bool admin;
  final Person? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t, b = ref.read(backendProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final act = comp.activeAt(now);
    final ents = comp.entries.values.toList()..sort((a, b) => a.rank.compareTo(b.rank));
    final next = competitionPoints(comp.startPoints, comp.entries.length + 1);
    final mine = me == null ? null : comp.entries[me!.id];

    Widget status;
    if (!act) {
      status = StateTag(t.ended, Tone.off);
    } else if (comp.deadline != null) {
      final left = comp.deadline!.difference(now);
      status = Text(left.isNegative ? t.timeUp : '⏱ ${fmtDuration(left)}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.red, fontFeatures: [FontFeature.tabularFigures()]));
    } else {
      status = StateTag(t.running, Tone.ok);
    }

    return OutlineCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('🏁 ${comp.title}', style: const TextStyle(fontWeight: FontWeight.w700))),
          status,
        ]),
        if (act) Muted(t.nextPlaceGets('$next')),
        if (me != null && act) ...[
          const SizedBox(height: 8),
          if (mine != null)
            StateTag('${t.yourPlace('${mine.rank}', '${mine.points}')} ${mine.status == Status.approved ? '✓' : '⏳'}',
                mine.status == Status.approved ? Tone.ok : Tone.wait)
          else
            Btn(t.iDidIt, kind: BtnKind.sun, expand: true, onPressed: () async {
              try {
                final r = await b.enterCompetition(comp.id);
                if (context.mounted) toast(context, t.yourRankToast('${r.rank}', '${r.points}'));
              } catch (e) {
                if (context.mounted) toast(context, errorText(t, e));
              }
            }),
        ],
        if (ents.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Muted(t.nobodyYet))
        else
          for (final e in ents)
            Builder(builder: (context) {
              final k = data.person(e.personId);
              return RowCard(margin: const EdgeInsets.only(top: 8), children: [
                MedalText(medal(e.rank - 1)),
                Expanded(child: k == null ? const Text('—') : MiniName(k)),
                if (e.status == Status.rejected)
                  StateTag(t.rejectedTag, Tone.off)
                else
                  Pts('${e.points}${e.status == Status.pending ? ' ⏳' : ''}'),
              ]);
            }),
        if (admin && act) ...[
          const SizedBox(height: 8),
          Btn(t.endComp, kind: BtnKind.ghost, small: true, onPressed: () => run(context, () => b.endCompetition(comp.id), ok: t.compEnded)),
        ],
      ]),
    );
  }
}
