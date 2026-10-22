import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/logic.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';
import 'competitions.dart';
import 'honor.dart';
import 'prayer_page.dart';
import 'prizes.dart';
import 'providers.dart';
import 'sheets.dart';
import 'shell.dart';
import 'theme.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');


class _Tile {
  const _Tile(this.page, this.icon, this.label, this.visible, [this.badge = 0]);
  final String page, label;
  final IconData icon;
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
    final unread = d.noticesFor(me).where((n) => n.activeAt(now) && !n.readBy.contains(me.id)).length;
    final tiles = [
      _Tile('approvals', Icons.fact_check_outlined, t.tileApprovals, can(me, Perm.approve), d.pendingCount()),
      _Tile('tasks', Icons.checklist_rounded, t.tileTasks, true),
      _Tile('addMember', Icons.person_add_alt_1_outlined, t.tileAddMember, can(me, Perm.addMembers)),
      _Tile('addAdmin', Icons.admin_panel_settings_outlined, t.tileAddAdmin, owner),
      _Tile('prayer', Icons.mosque_outlined, t.prayerTitle, owner),
      _Tile('honor', Icons.emoji_events_outlined, t.tileHonor, true),
      _Tile('alerts', Icons.campaign_outlined, t.tileAlerts, owner),
      // Delegated admins get the family's alerts too (the owner sees them all under "send alert").
      _Tile('inbox', Icons.notifications_none_rounded, t.tabNotices, !owner, unread),
      _Tile('comps', Icons.flag_outlined, t.tileComps, can(me, Perm.comps)),
    ].where((x) => x.visible);
    final active = d.competitions.where((x) => x.activeAt(now)).length;
    final perms = Perm.values.where((p) => me.perms[p] ?? false).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.adminDashboard),
      const SizedBox(height: 8),
      StatRow([
        StatBox('${d.members.length}', t.statMembers),
        StatBox('${d.familyEarnedFor(Span.daily)}', t.statTodayPoints),
        StatBox('$active', t.statActiveComps),
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
        final cols = (box.maxWidth / 150).floor().clamp(2, 4);
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final tile in tiles)
            SizedBox(
              width: w,
              height: 96,
              child: Material(
                color: context.pal.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Palette.sun.withValues(alpha: .7))),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push('/admin/${tile.page}'),
                  child: Stack(children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: context.pal.mintBg, borderRadius: BorderRadius.circular(12)),
                          child: Icon(tile.icon, color: context.pal.brandInk, size: 22),
                        ),
                        Text(tile.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2)),
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
      'tasks' => TasksPage(c),
      'alerts' => AlertsPage(c),
      'comps' => CompsPage(c),
      'prizes' => PrizesPage(c),
      'prayer' => PrayerPage(c),
      'honor' => HonorBoard(c),
      'inbox' => InboxPage(c),
      _ => const SizedBox(),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [BackLink(context.t.backToDashboard), body]);
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
              k == null ? const AvatarView('boy') : AvatarView.of(k),
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
                XButton(
                  icon: m.avatarLocked ? Icons.lock_outline : Icons.lock_open_outlined,
                  color: m.avatarLocked ? Palette.sunDeep : null,
                  tooltip: m.avatarLocked ? t.avatarLockOn : t.avatarLockOff,
                  onPressed: () => run(context, () => b.setAvatarLock(m.id, !m.avatarLocked), ok: !m.avatarLocked ? t.avatarLockOn : t.avatarLockOff),
                ),
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

/// Achievement report for today, this week, this month or this year, with a
/// button that sends it to the family as an alert (report permission).
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  var _s = Span.daily;

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data;
    final r = d.rankingFor(_s), fam = d.familyEarnedFor(_s);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileReports),
      SegTabs<Span>(tabs: spanTabs(t), value: _s, onChanged: (v) => setState(() => _s = v)),
      StatRow([
        StatBox('$fam', t.familyTotal),
        StatBox('${r.fold(0, (a, x) => a + x.done)}', t.doneCount, color: Palette.mint),
        StatBox('${r.fold(0, (a, x) => a + x.notDone)}', t.notDoneCount, color: Palette.red),
      ]),
      H3(t.ranking),
      if (r.isEmpty) EmptyState('📊', t.reportsEmpty),
      for (var i = 0; i < r.length; i++)
        RowCard(children: [
          MedalText(medal(i)),
          AvatarView.of(r[i].person, size: 40),
          Expanded(child: TitleSub(r[i].person.name, t.reportDoneLine('${r[i].done}', '${r[i].notDone}'))),
          Pts('${r[i].points}'),
        ]),
      if (can(widget.c.me, Perm.report)) ...[
        const SizedBox(height: 12),
        Muted(t.sendReportSub),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.pal.bg, borderRadius: BorderRadius.circular(14)),
          child: Text(reportText(context, d, DateTime.now(), _s)),
        ),
        Btn(t.sendToAll,
            expand: true,
            onPressed: d.members.isEmpty ? null : () => run(context, () => ref.read(backendProvider).sendReport(span: _s), ok: t.reportSent)),
      ],
    ]);
  }
}

String reportTitle(L10n t, Span s) => switch (s) {
      Span.daily => t.reportTitleDaily,
      Span.weekly => t.reportTitleWeekly,
      Span.monthly => t.reportTitleMonthly,
      Span.yearly => t.reportTitleYearly,
    };

String reportText(BuildContext context, FamilySnapshot d, DateTime now, [Span s = Span.daily]) {
  final t = context.t;
  final r = d.rankingFor(s);
  if (r.isEmpty) return t.reportNoMembers;
  final date = MaterialLocalizations.of(context).formatFullDate(now);
  return '${reportTitle(t, s)} — $date\n\n'
      '${[for (var i = 0; i < r.length; i++) t.reportLine(medal(i), r[i].person.name, '${r[i].points}', '${r[i].count}')].join('\n')}'
      '\n\n${t.reportTotal('${d.familyEarnedFor(s)}')}';
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
  // The member whose tasks are listed (one at a time, not the whole family).
  String? _view;
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
    final title = _title.text.trim(), pts = parseDigits(_pts.text) ?? 0;
    if (title.isEmpty || pts < 1) return toast(context, t.errTaskInput);
    final ok = await run(context, () => ref.read(backendProvider).addTask(title: title, personId: _who, points: pts, repeat: _rep), ok: t.taskAdded);
    if (ok) {
      _title.clear();
      if (_who != 'all') setState(() => _view = _who);
    }
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
    final pts = parseDigits(_ePts.text) ?? x.points;
    final ok = await run(context,
        () => ref.read(backendProvider).updateTask(taskId: x.id, title: _eTitle.text.trim(), personId: _eWho, points: pts < 1 ? x.points : pts, repeat: _eRep),
        ok: t.taskSaved);
    if (ok) setState(() => _editing = null);
  }

  Future<void> _delete(TaskItem x) async {
    final t = context.t;
    if (!await confirm(context, '${t.deleteTaskConfirm}\n«${x.title}»', ok: t.delete, danger: true) || !mounted) return;
    final ok = await run(context, () => ref.read(backendProvider).deleteTask(x.id), ok: t.deleted);
    if (ok && _editing == x.id) setState(() => _editing = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data;
    final edit = can(widget.c.me, Perm.tasks);
    final now = DateTime.now();
    final members = d.members;
    final memberItems = [for (final m in members) (m.id, m.name)];
    if (_who != 'all' && !members.any((m) => m.id == _who)) _who = 'all';
    if (_view == null || !members.any((m) => m.id == _view)) _view = members.firstOrNull?.id;
    final repItems = [for (final p in Period.values) (p, repeatLabel(t, p))];
    final view = _view == null ? null : d.person(_view!);
    final ts = view == null ? <TaskItem>[] : d.tasksOf(view.id, now);
    final done = <TaskItem>[], waiting = <TaskItem>[], open = <TaskItem>[];
    for (final x in ts) {
      final c = d.completionOf(x, now);
      (c == null ? open : c.status == Status.pending ? waiting : done).add(x);
    }

    Widget row(TaskItem x) {
      if (_editing == x.id) {
        return FormBox(margin: const EdgeInsets.only(bottom: 8), children: [
          TextField(controller: _eTitle, decoration: InputDecoration(hintText: t.taskTitleHint)),
          Two(
            Select<String>(value: _eWho, items: memberItems, onChanged: (v) => setState(() => _eWho = v)),
            Select<Period>(value: _eRep, items: repItems, onChanged: (v) => setState(() => _eRep = v)),
          ),
          Labeled(t.points, TextField(controller: _ePts, keyboardType: TextInputType.number)),
          // Full-width buttons so their labels never wrap or get cut.
          Row(children: [
            Expanded(child: Btn(t.save, onPressed: () => _save(x))),
            const SizedBox(width: 8),
            Expanded(child: Btn(t.cancel, kind: BtnKind.ghost, onPressed: () => setState(() => _editing = null))),
          ]),
          Btn(t.delete, kind: BtnKind.no, icon: Icons.delete_outline, expand: true, onPressed: () => _delete(x)),
        ]);
      }
      final comp = d.completionOf(x, now);
      final st = comp == null
          ? (x.prayer?.lateAt(now) ?? false ? StateTag(t.prayerLate, Tone.wait) : StateTag(t.notDone, Tone.off))
          : comp.status == Status.pending
              ? StateTag(t.waiting, Tone.wait)
              : StateTag(t.doneCheck, Tone.ok);
      return RowCard(children: [
        if (x.prayer != null) const Icon(Icons.mosque_outlined, color: Palette.sunDeep),
        Expanded(child: TitleSub(x.title, t.taskMeta(repeatLabel(t, x.repeat), '${x.points}'), done: comp?.status == Status.approved)),
        st,
        if (edit && x.prayer == null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            XButton(icon: Icons.edit_outlined, tooltip: t.edit, onPressed: () => _startEdit(x)),
            XButton(icon: Icons.delete_outline, color: Palette.red, tooltip: t.delete, onPressed: () => _delete(x)),
          ]),
      ]);
    }

    List<Widget> section(String title, List<TaskItem> xs) => [
          H3('$title (${xs.length})'),
          if (xs.isEmpty) Muted(t.noneHere),
          for (final x in xs) row(x),
        ];

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
              Labeled(t.forWhom, Select<String>(value: _who, label: t.forWhom, items: [('all', t.allMembers), ...memberItems], onChanged: (v) => setState(() => _who = v))),
              Labeled(t.repeat, Select<Period>(value: _rep, label: t.repeat, items: repItems, onChanged: (v) => setState(() => _rep = v))),
            ),
            Two(
              TextField(controller: _pts, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: t.points, semanticCounterText: t.points)),
              Btn(t.addTask, onPressed: _add),
            ),
          ]),
        H3(t.pickMember),
        // One member at a time: pick them, then see their done and not-done tasks.
        SizedBox(
          height: 92,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final m in members)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Semantics(
                  selected: m.id == _view,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      _view = m.id;
                      _editing = null;
                    }),
                    child: Container(
                      width: 70,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: m.id == _view ? context.pal.mintBg : null,
                        border: Border.all(color: m.id == _view ? Palette.brand : context.pal.line, width: m.id == _view ? 2 : 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(children: [
                        AvatarView.of(m, size: 46),
                        const SizedBox(height: 2),
                        Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        if (view != null) ...[
          ...section(t.notDoneTasks, open),
          if (waiting.isNotEmpty) ...section(t.pendingTasks, waiting),
          ...section(t.doneTasks, done),
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
  var _minutes = 0;
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
    final others = d.people.where((p) => p.id != widget.c.me.id).toList();
    if (_to != 'all' && !others.any((m) => m.id == _to)) _to = 'all';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tileAlerts),
      FormBox(children: [
        Select<String>(
          value: _to,
          label: t.to,
          items: [('all', t.allMembers), for (final m in others) (m.id, m.role == Role.member ? m.name : '${m.name} · ${roleLabel(t, m.role)}')],
          onChanged: (v) => setState(() => _to = v),
        ),
        TextField(controller: _body, minLines: 3, maxLines: 6, maxLength: 500, decoration: InputDecoration(hintText: t.alertBodyHint, counterText: '')),
        Labeled(
          t.alertDuration,
          Select<int>(
            value: _minutes,
            items: [(0, t.durNone), (30, t.dur30m), (60, t.dur1h), (180, t.dur3h), (1440, t.dur1d)],
            onChanged: (v) => setState(() => _minutes = v),
          ),
        ),
        Btn(t.sendAlert, onPressed: () async {
          final body = _body.text.trim();
          if (body.isEmpty) return toast(context, t.errAlertBody);
          final ok = await run(context, () => ref.read(backendProvider).sendAlert(_to, body, minutes: _minutes),
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
              XButton(tooltip: t.delete, onPressed: () => run(context, () => ref.read(backendProvider).deleteAlert(n.id), ok: t.alertDeleted)),
            ]),
            const SizedBox(height: 6),
            Muted(n.body),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Muted(ago(t, n.createdAt, now))),
              if (n.expiresAt != null)
                n.activeAt(now) ? StateTag(t.endsAt(clockTime(context, n.expiresAt!)), Tone.wait) : StateTag(t.alertEnded, Tone.off),
            ]),
          ]),
        ),
    ]);
  }
}

/// Alerts addressed to a delegated admin (or to everyone); opening it marks them read.
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(backendProvider).markRead().ignore());
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(context.t.tabNotices),
      NoticeList(widget.c.data.noticesFor(widget.c.me), now: now),
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
          final start = parseDigits(_start.text) ?? 20, mins = parseDigits(_mins.text) ?? 0;
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
