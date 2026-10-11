import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'common.dart';
import 'competitions.dart';
import 'providers.dart';
import 'sheets.dart';
import 'shell.dart';
import 'theme.dart';

const rewardEmoji = ['🏞️', '🍔', '🎮', '🍦', '🎡', '🎁', '📚', '🏖️'];

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool canEditAvatar(Person me, Person target) =>
    me.id == target.id || me.role == Role.owner || (target.role == Role.member && can(me, Perm.addMembers));

class _Tile {
  const _Tile(this.page, this.emoji, this.label, this.visible, [this.badge = 0]);
  final String page, emoji, label;
  final bool visible;
  final int badge;
}

class AdminHome extends ConsumerWidget {
  const AdminHome(this.c, {super.key});
  final Ctx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t, me = c.me, d = c.data;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final owner = me.role == Role.owner;
    final tiles = [
      _Tile('approvals', '✅', t.tileApprovals, can(me, Perm.approve), d.pendingCount()),
      _Tile('addAdmin', '🛡️', t.tileAddAdmin, owner),
      _Tile('addMember', '➕', t.tileAddMember, can(me, Perm.addMembers)),
      _Tile('reports', '📊', t.tileReports, can(me, Perm.viewReports) || can(me, Perm.report)),
      _Tile('sendReport', '🏆', t.tileSendReport, can(me, Perm.report)),
      _Tile('tasks', '📝', t.tileTasks, true),
      _Tile('alerts', '🔔', t.tileAlerts, owner),
      _Tile('comps', '🏁', t.tileComps, can(me, Perm.comps)),
      _Tile('rewards', '🎁', t.tileRewards, owner),
    ].where((x) => x.visible);
    final active = d.competitions.where((x) => x.activeAt(now)).length;
    final perms = Perm.values.where((p) => me.perms[p] ?? false).toList();

    Widget stat(int n, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.pal.bg, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('$n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.pal.brandInk)),
              Text(label, style: TextStyle(fontSize: 13, color: context.pal.muted)),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.adminDashboard),
      const SizedBox(height: 8),
      Row(children: [
        stat(d.members.length, t.statMembers),
        const SizedBox(width: 8),
        stat(d.familyEarned(Period.daily), t.statTodayPoints),
        const SizedBox(width: 8),
        stat(active, t.statActiveComps),
      ]),
      if (me.role == Role.admin) ...[
        const SizedBox(height: 12),
        Muted(t.yourPerms),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: [
          if (perms.isEmpty) Tag(t.viewTasksOnly),
          for (final p in perms) Tag(permLabel(t, p)),
        ]),
      ],
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, box) {
        final cols = (box.maxWidth / 155).floor().clamp(2, 4);
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final tile in tiles)
            SizedBox(
              width: w,
              child: Material(
                color: context.pal.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: context.pal.line)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push('/admin/${tile.page}'),
                  child: Stack(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tile.emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text(tile.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    if (tile.badge > 0) PositionedDirectional(top: 10, end: 10, child: Badge2(tile.badge)),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    ]);
  }
}

/// Wraps an admin sub-page with the "‹ لوحة المسؤول" back link.
class AdminPage extends ConsumerWidget {
  const AdminPage(this.page, this.c, {super.key});
  final String page;
  final Ctx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = switch (page) {
      'approvals' => ApprovalsPage(c),
      'addAdmin' => AddAdminPage(c),
      'addMember' => AddMemberPage(c),
      'reports' => ReportsPage(c),
      'sendReport' => SendReportPage(c),
      'tasks' => TasksPage(c),
      'alerts' => AlertsPage(c),
      'comps' => CompsPage(c),
      'rewards' => RewardsPage(c),
      _ => const SizedBox(),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), foregroundColor: context.pal.brandInk),
          child: Text(context.t.backToDashboard, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body,
    ]);
  }
}

// ------------------------------------------------------------------ approvals

class ApprovalsPage extends ConsumerWidget {
  const ApprovalsPage(this.c, {super.key});
  final Ctx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t, d = c.data, b = ref.read(backendProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final cs = d.completions.where((x) => x.status == Status.pending).toList();
    final es = [
      for (final comp in d.competitions)
        for (final e in comp.entries.values)
          if (e.status == Status.pending) (comp, e),
    ];
    final allowed = can(c.me, Perm.approve);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileApprovals),
      if (cs.isEmpty && es.isEmpty) EmptyState('✅', t.approvalsEmpty),
      if (cs.isNotEmpty) H3(t.tasksAwaiting),
      for (final x in cs)
        Builder(builder: (context) {
          final k = d.person(x.personId);
          return RowCard(children: [
            if (x.photoPath != null)
              ProofThumb(comp: x, onTap: () => showProof(context, ref, x, k, canDecide: allowed))
            else
              AvatarView(k?.avatar ?? 'boy'),
            Expanded(
              child: TitleSub(x.title,
                  '${k?.name ?? '—'} · ${t.pointsPlus('${x.points}')} · ${ago(t, x.createdAt, now)}${x.photoPath != null ? ' · ${t.photoAttached}' : ''}'),
            ),
            _Decide(
              onApprove: () => run(context, () => b.decideCompletion(x.id, true), ok: t.approvedToast('${x.points}', k?.name ?? '')),
              onReject: () => run(context, () => b.decideCompletion(x.id, false), ok: t.rejectedToast),
            ),
          ]);
        }),
      if (es.isNotEmpty) H3(t.compAchievements),
      for (final (comp, e) in es)
        Builder(builder: (context) {
          final k = d.person(e.personId);
          return RowCard(children: [
            MedalText(medal(e.rank - 1)),
            Expanded(child: TitleSub(comp.title, '${k?.name ?? '—'} · ${t.place('${e.rank}')} · ${t.pointsPlus('${e.points}')}')),
            _Decide(
              onApprove: () => run(context, () => b.decideEntry(comp.id, e.personId, true), ok: t.entryApprovedToast('${e.points}', k?.name ?? '')),
              onReject: () => run(context, () => b.decideEntry(comp.id, e.personId, false)),
            ),
          ]);
        }),
    ]);
  }
}

class _Decide extends StatelessWidget {
  const _Decide({required this.onApprove, required this.onReject});
  final VoidCallback onApprove, onReject;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Btn('✓', kind: BtnKind.ok, onPressed: onApprove, semantic: context.t.approve),
        const SizedBox(width: 6),
        Btn('✕', kind: BtnKind.no, onPressed: onReject, semantic: context.t.reject),
      ]);
}

// ------------------------------------------------------------------ people

String? _checkNameEmail(BuildContext context, String name, String email, FamilySnapshot d) {
  if (name.isEmpty || !_emailRe.hasMatch(email)) return context.t.errNameEmail;
  if (d.people.any((p) => p.email == email)) return context.t.errEmailTaken;
  return null;
}

class AddAdminPage extends ConsumerStatefulWidget {
  const AddAdminPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<AddAdminPage> createState() => _AddAdminPageState();
}

class _AddAdminPageState extends ConsumerState<AddAdminPage> {
  final _name = TextEditingController(), _email = TextEditingController();
  var _avatar = 'mom';
  final _perms = {for (final p in Perm.values) p: false};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final t = context.t;
    final name = _name.text.trim(), email = _email.text.trim().toLowerCase();
    final err = _checkNameEmail(context, name, email, widget.c.data);
    if (err != null) return toast(context, err);
    final ok = await run(context,
        () => ref.read(backendProvider).addPerson(role: Role.admin, name: name, email: email, avatar: _avatar, perms: Map.of(_perms)),
        ok: t.inviteSent(email));
    if (ok) {
      _name.clear();
      _email.clear();
      setState(() => _perms.updateAll((k, v) => false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, me = widget.c.me, b = ref.read(backendProvider);
    final admins = d.people.where((p) => p.role != Role.member);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileAddAdmin),
      Muted(t.addAdminSub),
      FormBox(children: [
        TextField(controller: _name, decoration: InputDecoration(hintText: t.adminNameHint)),
        Muted(t.avatarLabel),
        AvatarGrid(selected: _avatar, onPick: (k) => setState(() => _avatar = k)),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: InputDecoration(hintText: t.emailHint2)),
        _PermsBox(
          title: t.delegatedPerms,
          perms: _perms,
          onChanged: (p, v) => setState(() => _perms[p] = v),
          footer: t.viewOnlyNote,
        ),
        Btn(t.addAndSend, onPressed: _add),
      ]),
      H3(t.admins),
      for (final a in admins)
        if (a.role == Role.owner)
          RowCard(children: [
            EditableAvatar(person: a, canEdit: canEditAvatar(me, a), onTap: () => showAvatarPicker(context, ref, a)),
            Expanded(child: TitleSub(a.name, t.mainOwner)),
          ])
        else
          OutlineCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                EditableAvatar(person: a, canEdit: canEditAvatar(me, a), onTap: () => showAvatarPicker(context, ref, a)),
                const SizedBox(width: 8),
                Expanded(child: TitleSub(a.name, a.email, subLtr: true)),
                StateTag(a.active ? t.linked : t.pendingVerification, a.active ? Tone.ok : Tone.wait),
              ]),
              const SizedBox(height: 8),
              _PermsBox(
                perms: a.perms,
                background: context.pal.bg,
                onChanged: (p, v) {
                  final next = {...a.perms, p: v};
                  run(context, () => b.updatePerms(a.id, next), ok: t.permsUpdated(a.name));
                },
              ),
              const SizedBox(height: 8),
              Wrap(alignment: WrapAlignment.end, spacing: 6, children: [
                if (!a.active)
                  Btn(t.resendCode, kind: BtnKind.ghost, small: true, onPressed: () => run(context, () => b.resendInvite(a.id), ok: t.inviteSent(a.email))),
                Btn(t.remove, kind: BtnKind.no, small: true, onPressed: () async {
                  if (await confirm(context, t.confirmRemove(a.name)) && context.mounted) await run(context, () => b.removePerson(a.id));
                }),
              ]),
            ]),
          ),
    ]);
  }
}

class _PermsBox extends StatelessWidget {
  const _PermsBox({required this.perms, required this.onChanged, this.title, this.footer, this.background});
  final Map<Perm, bool> perms;
  final void Function(Perm, bool) onChanged;
  final String? title, footer;
  final Color? background;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: background ?? context.pal.card, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final p in Perm.values)
          InkWell(
            onTap: () => onChanged(p, !(perms[p] ?? false)),
            child: Row(children: [
              Checkbox(value: perms[p] ?? false, onChanged: (v) => onChanged(p, v ?? false), visualDensity: VisualDensity.compact),
              Expanded(child: Text(permLabel(t, p), style: const TextStyle(fontSize: 14))),
            ]),
          ),
        if (footer != null) Muted(footer!),
      ]),
    );
  }
}

class AddMemberPage extends ConsumerStatefulWidget {
  const AddMemberPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends ConsumerState<AddMemberPage> {
  final _name = TextEditingController(), _email = TextEditingController();
  var _avatar = 'boy';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final t = context.t;
    final name = _name.text.trim(), email = _email.text.trim().toLowerCase();
    final err = _checkNameEmail(context, name, email, widget.c.data);
    if (err != null) return toast(context, err);
    final ok = await run(context, () => ref.read(backendProvider).addPerson(role: Role.member, name: name, email: email, avatar: _avatar),
        ok: t.inviteSent(email));
    if (ok) {
      _name.clear();
      _email.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, me = widget.c.me, b = ref.read(backendProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileAddMember),
      Muted(t.addMemberSub),
      FormBox(children: [
        TextField(controller: _name, decoration: InputDecoration(hintText: t.nameHint)),
        Muted(t.avatarLabel),
        AvatarGrid(selected: _avatar, onPick: (k) => setState(() => _avatar = k)),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: InputDecoration(hintText: t.emailHint2)),
        Btn(t.addAndSend, onPressed: _add),
      ]),
      H3(t.familyMembersTitle),
      if (d.members.isEmpty) EmptyState('👨‍👩‍👧', t.noMembers),
      for (final m in d.members)
        RowCard(children: [
          EditableAvatar(person: m, canEdit: canEditAvatar(me, m), onTap: () => showAvatarPicker(context, ref, m)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TitleSub(m.name, m.email, subLtr: true),
              const SizedBox(height: 6),
              Row(children: [
                StateTag(m.active ? t.linked : t.pendingVerification, m.active ? Tone.ok : Tone.wait),
                const Spacer(),
                if (!m.active)
                  XButton(icon: Icons.refresh, tooltip: t.resendCode, onPressed: () => run(context, () => b.resendInvite(m.id), ok: t.inviteSent(m.email))),
                XButton(
                  tooltip: t.remove,
                  onPressed: () async {
                    if (await confirm(context, t.confirmRemove(m.name)) && context.mounted) await run(context, () => b.removePerson(m.id));
                  },
                ),
              ]),
            ]),
          ),
        ]),
    ]);
  }
}

// ------------------------------------------------------------------ reports

class ReportsPage extends StatefulWidget {
  const ReportsPage(this.c, {super.key});
  final Ctx c;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  var _p = Period.daily;

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data;
    final r = d.ranking(_p), fam = d.familyEarned(_p), ft = tierOf(d.tiers, fam, _p, Scope.family);
    Widget stat(int n, String l) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.pal.bg, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('$n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.pal.brandInk)),
              Text(l, style: TextStyle(fontSize: 13, color: context.pal.muted)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileReports),
      SegTabs<Period>(tabs: [(Period.daily, t.today, 0), (Period.weekly, t.thisWeek, 0)], value: _p, onChanged: (v) => setState(() => _p = v)),
      Row(children: [stat(fam, t.familyTotal), const SizedBox(width: 8), stat(r.fold(0, (a, x) => a + x.count), t.achievements)]),
      if (ft != null)
        TierBox(
          margin: const EdgeInsets.only(top: 10),
          emoji: ft.emoji,
          child: Text.rich(TextSpan(children: [TextSpan(text: '${t.familyEarned} '), TextSpan(text: ft.name, style: const TextStyle(fontWeight: FontWeight.w700))])),
        ),
      H3(t.ranking),
      if (r.isEmpty) EmptyState('📊', t.reportsEmpty),
      for (var i = 0; i < r.length; i++)
        Builder(builder: (context) {
          final x = r[i], tier = tierOf(d.tiers, x.points, _p, Scope.each);
          return RowCard(children: [
            MedalText(medal(i)),
            AvatarView(x.person.avatar),
            Expanded(child: TitleSub(x.person.name, '${t.countAchievements('${x.count}')}${tier != null ? ' · ${t.earnedTier('${tier.emoji} ${tier.name}')}' : ''}')),
            Pts('${x.points}'),
          ]);
        }),
    ]);
  }
}

String reportText(BuildContext context, FamilySnapshot d, DateTime now) {
  final t = context.t;
  final r = d.ranking(Period.daily);
  if (r.isEmpty) return t.reportNoMembers;
  final date = MaterialLocalizations.of(context).formatFullDate(now);
  return '${t.reportTitleLine(date)}\n\n'
      '${[for (var i = 0; i < r.length; i++) t.reportLine(medal(i), r[i].person.name, '${r[i].points}', '${r[i].count}')].join('\n')}'
      '\n\n${t.reportTotal('${d.familyEarned(Period.daily)}')}';
}

class SendReportPage extends ConsumerWidget {
  const SendReportPage(this.c, {super.key});
  final Ctx c;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileSendReport),
      Muted(t.sendReportSub),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.pal.bg, borderRadius: BorderRadius.circular(14)),
        child: Text(reportText(context, c.data, DateTime.now())),
      ),
      Btn(t.sendToAll,
          expand: true,
          onPressed: c.data.members.isEmpty ? null : () => run(context, () => ref.read(backendProvider).sendReport(), ok: t.reportSent)),
    ]);
  }
}

// ------------------------------------------------------------------ tasks

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final _title = TextEditingController(), _pts = TextEditingController(text: '10');
  String _who = 'all';
  var _rep = Period.daily;
  String? _editing;
  final _eTitle = TextEditingController(), _ePts = TextEditingController();
  String _eWho = '';
  var _eRep = Period.daily;

  @override
  void dispose() {
    for (final c in [_title, _pts, _eTitle, _ePts]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    final t = context.t;
    final title = _title.text.trim(), pts = int.tryParse(_pts.text.trim()) ?? 0;
    if (title.isEmpty || pts < 1) return toast(context, t.errTaskInput);
    final ok = await run(context, () => ref.read(backendProvider).addTask(title: title, personId: _who, points: pts, repeat: _rep), ok: t.taskAdded);
    if (ok) _title.clear();
  }

  void _startEdit(TaskItem x) => setState(() {
        _editing = x.id;
        _eTitle.text = x.title;
        _ePts.text = '${x.points}';
        _eWho = x.personId;
        _eRep = x.repeat;
      });

  Future<void> _save(TaskItem x) async {
    final t = context.t;
    final pts = int.tryParse(_ePts.text.trim()) ?? x.points;
    final ok = await run(context,
        () => ref.read(backendProvider).updateTask(taskId: x.id, title: _eTitle.text.trim(), personId: _eWho, points: pts < 1 ? x.points : pts, repeat: _eRep),
        ok: t.taskSaved);
    if (ok) setState(() => _editing = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, b = ref.read(backendProvider);
    final edit = can(widget.c.me, Perm.tasks);
    final now = DateTime.now();
    final members = d.members;
    final memberItems = [for (final m in members) (m.id, m.name)];
    if (_who != 'all' && !members.any((m) => m.id == _who)) _who = 'all';
    final repItems = [(Period.daily, t.dailyF), (Period.weekly, t.weeklyF)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileTasks),
      Muted(edit ? t.tasksEditSub : t.tasksViewOnly),
      if (members.isEmpty)
        EmptyState('📝', t.addMembersFirst)
      else ...[
        if (edit)
          FormBox(children: [
            TextField(controller: _title, decoration: InputDecoration(hintText: t.taskTitleHint)),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in t.taskPresets.split('|'))
                ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 14)),
                  backgroundColor: context.pal.card,
                  side: BorderSide(color: context.pal.line),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _title.text = p,
                ),
            ]),
            Two(
              Select<String>(value: _who, label: t.forWhom, items: [...memberItems, ('all', t.allMembers)], onChanged: (v) => setState(() => _who = v)),
              Select<Period>(value: _rep, label: t.repeat, items: repItems, onChanged: (v) => setState(() => _rep = v)),
            ),
            Two(
              TextField(controller: _pts, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: t.points, semanticCounterText: t.points)),
              Btn(t.addTask, onPressed: _add),
            ),
          ]),
        for (final m in members) ...[
          H3(m.name, leading: AvatarView(m.avatar, size: 26)),
          if (!d.tasks.any((x) => x.personId == m.id)) Muted(t.noTasks),
          for (final x in d.tasks.where((x) => x.personId == m.id))
            if (_editing == x.id)
              FormBox(margin: const EdgeInsets.only(bottom: 8), children: [
                TextField(controller: _eTitle),
                Two(
                  Select<String>(value: _eWho, items: memberItems, onChanged: (v) => setState(() => _eWho = v)),
                  Select<Period>(value: _eRep, items: repItems, onChanged: (v) => setState(() => _eRep = v)),
                ),
                Two(
                  TextField(controller: _ePts, keyboardType: TextInputType.number),
                  Row(children: [
                    Expanded(child: Btn(t.save, onPressed: () => _save(x))),
                    const SizedBox(width: 6),
                    Expanded(child: Btn(t.cancel, kind: BtnKind.ghost, onPressed: () => setState(() => _editing = null))),
                  ]),
                ),
              ])
            else
              Builder(builder: (context) {
                final comp = d.completionOf(x, now);
                final st = comp == null
                    ? StateTag(t.notDone, Tone.off)
                    : comp.status == Status.pending
                        ? StateTag(t.waiting, Tone.wait)
                        : StateTag(t.doneCheck, Tone.ok);
                return RowCard(children: [
                  Expanded(child: TitleSub(x.title, t.taskMeta(x.repeat == Period.daily ? t.dailyF : t.weeklyF, '${x.points}'))),
                  st,
                  if (edit)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      XButton(icon: Icons.edit_outlined, tooltip: t.edit, onPressed: () => _startEdit(x)),
                      XButton(tooltip: t.delete, onPressed: () => run(context, () => b.deleteTask(x.id))),
                    ]),
                ]);
              }),
        ],
      ],
    ]);
  }
}

// ------------------------------------------------------------------ alerts

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  var _to = 'all';
  final _body = TextEditingController();

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    if (_to != 'all' && !d.members.any((m) => m.id == _to)) _to = 'all';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileAlerts),
      FormBox(children: [
        Select<String>(
          value: _to,
          label: t.to,
          items: [('all', t.allMembers), for (final m in d.members) (m.id, m.name)],
          onChanged: (v) => setState(() => _to = v),
        ),
        TextField(controller: _body, minLines: 3, maxLines: 6, maxLength: 500, decoration: InputDecoration(hintText: t.alertBodyHint, counterText: '')),
        Btn(t.sendAlert, onPressed: () async {
          final body = _body.text.trim();
          if (body.isEmpty) return toast(context, t.errAlertBody);
          final ok = await run(context, () => ref.read(backendProvider).sendAlert(_to, body),
              ok: _to == 'all' ? t.alertSentAll : t.alertSentTo(d.person(_to)?.name ?? ''));
          if (ok) _body.clear();
        }),
      ]),
      H3(t.lastSent),
      if (d.notices.isEmpty) EmptyState('🔔', t.noAlerts),
      for (final n in d.notices.take(8))
        OutlineCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Muted(n.to == 'all' ? t.toAll : t.toName(d.person(n.to)?.name ?? '—')),
            ]),
            const SizedBox(height: 6),
            Muted(n.body),
            const SizedBox(height: 4),
            Muted(ago(t, n.createdAt, now)),
          ]),
        ),
    ]);
  }
}

// ------------------------------------------------------------------ competitions (admin)

class CompsPage extends ConsumerStatefulWidget {
  const CompsPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<CompsPage> createState() => _CompsPageState();
}

class _CompsPageState extends ConsumerState<CompsPage> {
  final _title = TextEditingController(), _start = TextEditingController(text: '20'), _mins = TextEditingController();

  @override
  void dispose() {
    for (final c in [_title, _start, _mins]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileComps),
      Muted(t.compsSub),
      FormBox(children: [
        TextField(controller: _title, decoration: InputDecoration(hintText: t.compTitleHint)),
        Two(
          Labeled(t.firstPlacePoints, TextField(controller: _start, keyboardType: TextInputType.number)),
          Labeled(t.timerMinutes, TextField(controller: _mins, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: t.noTimer))),
        ),
        Btn(t.launchComp, onPressed: () async {
          final title = _title.text.trim();
          if (title.isEmpty) return toast(context, t.errCompTitle);
          final start = int.tryParse(_start.text.trim()) ?? 20, mins = int.tryParse(_mins.text.trim()) ?? 0;
          final ok = await run(context,
              () => ref.read(backendProvider).addCompetition(title: title, startPoints: start < 1 ? 20 : start, minutes: mins < 0 ? 0 : mins),
              ok: t.compLaunched);
          if (ok) {
            _title.clear();
            _mins.clear();
          }
        }),
      ]),
      if (d.competitions.isEmpty) EmptyState('🏁', t.noComps),
      for (final comp in d.competitions) CompCard(comp: comp, data: d, admin: true),
    ]);
  }
}

// ------------------------------------------------------------------ rewards

class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
  final _name = TextEditingController(), _thr = TextEditingController(text: '66');
  var _emoji = rewardEmoji.first;
  var _period = Period.weekly;
  var _scope = Scope.each;

  @override
  void dispose() {
    _name.dispose();
    _thr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, b = ref.read(backendProvider);
    final now = DateTime.now();
    final groups = [
      for (final p in Period.values)
        for (final s in Scope.values)
          if (d.tiers.any((x) => x.period == p && x.scope == s))
            (p, s, d.tiers.where((x) => x.period == p && x.scope == s).toList()..sort((a, b) => b.threshold.compareTo(a.threshold))),
    ];
    final due = <({String who, Tier tier, String whoKey, String pk})>[];
    for (final p in Period.values) {
      for (final m in d.members) {
        final tier = tierOf(d.tiers, d.earned(m.id, p), p, Scope.each);
        if (tier != null) due.add((who: m.name, tier: tier, whoKey: m.id, pk: periodKey(p, now)));
      }
      final ft = tierOf(d.tiers, d.familyEarned(p), p, Scope.family);
      if (ft != null) due.add((who: t.wholeFamily, tier: ft, whoKey: 'family', pk: periodKey(p, now)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileRewards),
      Muted(t.rewardsSub),
      FormBox(children: [
        Two(
          TextField(controller: _name, decoration: InputDecoration(hintText: t.rewardNameHint)),
          Select<String>(value: _emoji, label: t.icon, items: [for (final e in rewardEmoji) (e, e)], onChanged: (v) => setState(() => _emoji = v)),
        ),
        Two(
          Labeled(t.minPoints, TextField(controller: _thr, keyboardType: TextInputType.number)),
          Labeled(t.period, Select<Period>(value: _period, items: [(Period.weekly, t.weeklyF), (Period.daily, t.dailyF)], onChanged: (v) => setState(() => _period = v))),
        ),
        Labeled(t.countedFor, Select<Scope>(value: _scope, items: [(Scope.each, t.scopeEach), (Scope.family, t.scopeFamily)], onChanged: (v) => setState(() => _scope = v))),
        Btn(t.addTier, onPressed: () async {
          final name = _name.text.trim(), thr = int.tryParse(_thr.text.trim()) ?? 0;
          if (name.isEmpty || thr < 1) return toast(context, t.errTierInput);
          final ok = await run(context, () => b.addTier(name: name, emoji: _emoji, threshold: thr, period: _period, scope: _scope), ok: t.tierAdded);
          if (ok) _name.clear();
        }),
      ]),
      if (groups.isEmpty) EmptyState('🎁', t.noTiers),
      for (final (p, s, tiers) in groups) ...[
        H3('${p == Period.daily ? t.dailyF : t.weeklyF} · ${s == Scope.each ? t.groupEach : t.groupFamily}'),
        for (final x in tiers)
          RowCard(children: [
            EmojiCircle(x.emoji),
            Expanded(child: Text(x.name, style: const TextStyle(fontWeight: FontWeight.w700))),
            Pts(t.tierPoints('${x.threshold}')),
            XButton(tooltip: t.delete, onPressed: () => run(context, () => b.deleteTier(x.id))),
          ]),
      ],
      if (groups.isNotEmpty) ...[
        H3(t.dueNow),
        if (due.isEmpty) Muted(t.noDue),
        for (final x in due)
          RowCard(children: [
            EmojiCircle(x.tier.emoji),
            Expanded(child: TitleSub(x.tier.name, '${x.who} · ${x.tier.period == Period.daily ? t.daily : t.weekly}')),
            if (d.deliveries.contains('${x.tier.id}_${x.whoKey}_${x.pk}'))
              StateTag(t.delivered, Tone.ok)
            else
              Btn(t.markDelivered, kind: BtnKind.ok, small: true, onPressed: () => run(context, () => b.deliver(x.tier.id, x.whoKey, x.pk), ok: t.deliveredToast)),
          ]),
      ],
    ]);
  }
}
