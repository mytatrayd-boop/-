import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

/// Honor board: members ranked by points this month / this year, and the
/// family's goals (e.g. read 12 books this year). Admins with the tasks
/// permission add goals and move their progress; members only see them.
class HonorBoard extends ConsumerStatefulWidget {
  const HonorBoard(this.c, {super.key, this.title = true});
  final Ctx c;
  final bool title;
  @override
  ConsumerState<HonorBoard> createState() => _HonorBoardState();
}

class _HonorBoardState extends ConsumerState<HonorBoard> {
  var _h = Honor.monthly;
  var _goalPeriod = Honor.yearly;
  var _goalFor = 'family';
  final _title = TextEditingController(), _target = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, me = widget.c.me;
    final b = ref.read(backendProvider);
    final edit = can(me, Perm.tasks);
    final r = d.honorRanking(_h).where((x) => x.points > 0).toList();
    // Members see the family's goals and their own; admins see all.
    final goals = d.goals.where((g) => g.period == _h && (me.role != Role.member || g.personId == 'family' || g.personId == me.id)).toList();
    if (_goalFor != 'family' && !d.members.any((m) => m.id == _goalFor)) _goalFor = 'family';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.title) ...[H2(t.tileHonor), Muted(t.honorSub)],
      SegTabs<Honor>(tabs: [(Honor.monthly, t.thisMonth, 0), (Honor.yearly, t.thisYear, 0)], value: _h, onChanged: (v) => setState(() => _h = v)),
      if (r.isEmpty) EmptyState('🏆', t.honorEmpty),
      for (var i = 0; i < r.length; i++)
        RowCard(children: [
          MedalText(medal(i)),
          AvatarView.of(r[i].person, size: 40),
          Expanded(child: TitleSub(r[i].person.name, t.countAchievements('${r[i].count}'))),
          Pts('${r[i].points}'),
        ]),
      Muted(t.honorNote),
      H3('🎯 ${t.familyGoals}'),
      if (goals.isEmpty) Muted(edit ? t.noGoals : t.noGoalsMember),
      for (final g in goals)
        OutlineCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: TitleSub(g.title, g.personId == 'family' ? t.wholeFamily : t.goalForName(d.person(g.personId)?.name ?? '—')),
              ),
              if (g.reached) StateTag(t.goalReached, Tone.ok) else Pts('${g.progress}/${g.target}'),
              if (edit) ...[
                IconButton(
                  tooltip: t.goalMinus,
                  onPressed: g.progress > 0 ? () => run(context, () => b.goalProgress(g.id, -1)) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: t.goalPlus,
                  color: Palette.mint,
                  onPressed: g.reached ? null : () => run(context, () => b.goalProgress(g.id, 1)),
                  icon: const Icon(Icons.add_circle),
                ),
                XButton(tooltip: t.delete, onPressed: () => run(context, () => b.deleteGoal(g.id))),
              ],
            ]),
            ProgressBar(g.target == 0 ? 0 : g.progress / g.target),
          ]),
        ),
      if (edit)
        FormBox(children: [
          TextField(controller: _title, maxLength: 80, decoration: InputDecoration(hintText: t.goalTitleHint, counterText: '')),
          Two(
            Labeled(t.goalTarget, TextField(controller: _target, keyboardType: TextInputType.number)),
            Labeled(
              t.goalPeriod,
              Select<Honor>(
                value: _goalPeriod,
                items: [(Honor.monthly, t.monthlyGoal), (Honor.yearly, t.yearlyGoal)],
                onChanged: (v) => setState(() => _goalPeriod = v),
              ),
            ),
          ),
          Labeled(
            t.goalFor,
            Select<String>(
              value: _goalFor,
              items: [('family', t.wholeFamily), for (final m in d.members) (m.id, m.name)],
              onChanged: (v) => setState(() => _goalFor = v),
            ),
          ),
          Btn(t.addGoal, onPressed: () async {
            final title = _title.text.trim(), target = parseDigits(_target.text) ?? 0;
            if (title.isEmpty || target < 1) return toast(context, t.errGoalInput);
            final ok = await run(context, () => b.addGoal(title: title, target: target, personId: _goalFor, period: _goalPeriod), ok: t.goalAdded);
            if (ok) {
              _title.clear();
              _target.clear();
              setState(() => _h = _goalPeriod);
            }
          }),
        ]),
    ]);
  }
}
