import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'common.dart';
import 'competitions.dart';
import 'honor.dart';
import 'prizes.dart';
import 'providers.dart';
import 'sheets.dart';
import 'shell.dart';
import 'theme.dart';

enum MTab { tasks, comps, rewards, notes }

class MemberHome extends ConsumerStatefulWidget {
  const MemberHome(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<MemberHome> createState() => _MemberHomeState();
}

class _MemberHomeState extends ConsumerState<MemberHome> {
  var _tab = MTab.tasks;
  final _busy = <String>{};

  Future<void> _done(TaskItem x, {bool withPhoto = false}) async {
    final t = context.t;
    Uint8List? photo;
    if (withPhoto) {
      final src = await openSheet<ImageSource>(context, (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetHeader(c.t.attachProof),
            ListTile(leading: const Text('📷', style: TextStyle(fontSize: 22)), title: Text(c.t.camera), onTap: () => Navigator.pop(c, ImageSource.camera)),
            ListTile(leading: const Text('🖼️', style: TextStyle(fontSize: 22)), title: Text(c.t.gallery), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          ]));
      if (src == null || !mounted) return;
      try {
        // Resized and compressed on device (the prototype used 720px / JPEG .72).
        final f = await ImagePicker().pickImage(source: src, maxWidth: 720, maxHeight: 720, imageQuality: 72);
        if (f == null) return;
        photo = await f.readAsBytes();
      } catch (_) {
        if (mounted) toast(context, t.errImage);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _busy.add(x.id));
    await run(context, () => ref.read(backendProvider).completeTask(x.id, photo: photo), ok: photo != null ? t.sentWithPhoto : t.sentForApproval);
    if (mounted) setState(() => _busy.remove(x.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, u = widget.c.me;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final ts = d.tasksOf(u.id, now);
    final done = ts.where((x) => d.completionOf(x, now)?.status == Status.approved).length;
    final pct = ts.isEmpty ? 0.0 : done / ts.length;
    final notes = d.noticesFor(u);
    final unread = notes.where((n) => n.activeAt(now) && !n.readBy.contains(u.id)).length;
    final openC = d.competitions.where((x) => x.activeAt(now) && !x.entries.containsKey(u.id)).length;

    final body = switch (_tab) {
      MTab.tasks => _tasks(context, ts, now),
      MTab.comps => _comps(context, now),
      MTab.rewards => _rewards(context),
      MTab.notes => NoticeList(notes, now: now),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFF0D9A6), Palette.sun, Palette.sunDeep], stops: [0, .55, 1]),
            boxShadow: [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 0)],
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${d.earned(u.id, Span.weekly)}',
                style: const TextStyle(fontFamily: headFont, fontSize: 30, height: 1, color: Palette.onSun, fontVariations: [FontVariation('wght', 800)])),
            Text(t.weekPoints, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Palette.onSun)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H2(t.helloMember(u.name)),
            Muted(t.todaySummary('${d.earned(u.id, Span.daily)}', '$done', '${ts.length}')),
            ProgressBar(pct),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      // Their place today, this week, month and year, and their own report.
      Row(children: [
        for (final s in Span.values) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              decoration: BoxDecoration(color: context.pal.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.sun.withValues(alpha: .6))),
              child: Column(children: [
                Text(medalOrPlace(d.placeOf(u.id, s)), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.pal.brandInk)),
                Text(spanLabel(t, s), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: context.pal.muted)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Btn(t.myReport, small: true, icon: Icons.insert_chart_outlined, onPressed: () => context.go('/report')),
      ]),
      SegTabs<MTab>(
        tabs: [(MTab.tasks, t.tabMyTasks, 0), (MTab.comps, t.tabComps, openC), (MTab.rewards, t.tabRewards, 0), (MTab.notes, t.tabNotices, unread)],
        value: _tab,
        onChanged: (v) {
          setState(() => _tab = v);
          if (v == MTab.notes && unread > 0) ref.read(backendProvider).markRead().ignore();
        },
      ),
      body,
    ]);
  }

  Widget _tasks(BuildContext context, List<TaskItem> ts, DateTime now) {
    final t = context.t, d = widget.c.data;
    if (ts.isEmpty) return EmptyState('🌤️', t.noTasksNow);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final x in ts)
        Builder(builder: (context) {
          final c = d.completionOf(x, now);
          final busy = _busy.contains(x.id);
          final late = x.prayer != null && c == null && x.prayer!.lateAt(now);
          final Widget s = c == null
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  if (x.prayer == null) ...[
                    XButton(icon: Icons.photo_camera_outlined, tooltip: t.doneWithPhoto, onPressed: busy ? () {} : () => _done(x, withPhoto: true)),
                    const SizedBox(width: 2),
                  ],
                  Btn(t.doneIt, kind: BtnKind.sun, onPressed: busy ? null : () => _done(x)),
                ])
              : c.status == Status.pending
                  ? StateTag('${t.awaitingApproval}${c.photoPath != null ? ' 📷' : ''}', Tone.wait)
                  : StateTag('+${c.points} ✓', Tone.ok);
          final when = x.prayer != null
              ? (late ? t.prayerLate : t.prayerNow)
              : switch (x.repeat) {
                  Period.daily => t.todayLabel,
                  Period.weekly => t.weekLabel,
                  Period.monthly => t.thisMonthLabel,
                  Period.yearly => t.thisYearLabel,
                  Period.once => t.onceF,
                };
          return RowCard(children: [
            if (x.prayer != null) Icon(Icons.mosque_outlined, color: late ? Palette.red : Palette.sunDeep),
            Expanded(child: TitleSub(x.title, t.memberTaskMeta(when, '${x.points}'), done: c?.status == Status.approved)),
            s,
          ]);
        }),
      const SizedBox(height: 10),
      Muted(t.photoOptional),
    ]);
  }

  Widget _comps(BuildContext context, DateTime now) {
    final t = context.t, d = widget.c.data;
    if (d.competitions.isEmpty) return EmptyState('🏁', t.noCompsMember);
    final act = d.competitions.where((x) => x.activeAt(now));
    final old = d.competitions.where((x) => !x.activeAt(now)).take(5);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final x in act) CompCard(comp: x, data: d, me: widget.c.me),
      if (old.isNotEmpty) ...[
        H3(t.pastComps),
        for (final x in old) CompCard(comp: x, data: d, me: widget.c.me),
      ],
    ]);
  }

  Widget _rewards(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PrizesPage(widget.c),
        const SizedBox(height: 8),
        H2('🏆 ${context.t.tileHonor}'),
        HonorBoard(widget.c, title: false),
      ]);
}

/// 🥇🥈🥉 for the first three places, the number after.
String medalOrPlace(int place) => medal(place - 1);
