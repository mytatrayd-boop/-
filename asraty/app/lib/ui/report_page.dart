import 'package:flutter/material.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'admin.dart';
import 'common.dart';
import 'member.dart';
import 'shell.dart';
import 'theme.dart';

/// Bottom-bar "reports": a member's own report, or the family report for admins.
class ReportRoute extends StatelessWidget {
  const ReportRoute(this.c, {super.key});
  final Ctx c;
  @override
  Widget build(BuildContext context) => c.me.role == Role.member ? MyReportPage(c) : ReportsPage(c);
}

/// A member's report for the day, week, month or year: their place, points,
/// done and not-done tasks, and where everyone stands.
class MyReportPage extends StatefulWidget {
  const MyReportPage(this.c, {super.key});
  final Ctx c;
  @override
  State<MyReportPage> createState() => _MyReportPageState();
}

class _MyReportPageState extends State<MyReportPage> {
  var _s = Span.daily;

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, u = widget.c.me;
    final r = d.rankingFor(_s);
    final mine = r.where((x) => x.person.id == u.id).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.myReport),
      SegTabs<Span>(tabs: spanTabs(t), value: _s, onChanged: (v) => setState(() => _s = v)),
      StatRow([
        StatBox(medalOrPlace(d.placeOf(u.id, _s)), t.rankIn('', '${d.members.length}').trim()),
        StatBox('${mine?.points ?? 0}', t.pointsWord),
        StatBox('${mine?.done ?? 0}', t.doneCount, color: Palette.mint),
        StatBox('${mine?.notDone ?? 0}', t.notDoneCount, color: Palette.red),
      ]),
      H3(t.ranking),
      for (var i = 0; i < r.length; i++)
        Container(
          decoration: r[i].person.id == u.id ? BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.sun, width: 2)) : null,
          margin: const EdgeInsets.only(bottom: 8),
          child: RowCard(margin: EdgeInsets.zero, children: [
            MedalText(medal(i)),
            AvatarView.of(r[i].person, size: 36),
            Expanded(child: TitleSub(r[i].person.name, t.countAchievements('${r[i].count}'))),
            Pts('${r[i].points}'),
          ]),
        ),
    ]);
  }
}
