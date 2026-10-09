import 'package:flutter/material.dart';
import '../core/payout_rules.dart';
import '../core/settings.dart';
import '../main.dart';
import '../model/programs.dart';
import 'common.dart';

class MonthPage extends StatefulWidget {
  final AppState state;
  final DateTime today;
  final void Function(Program) onOpen;
  const MonthPage({super.key, required this.state, required this.today, required this.onOpen});
  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  late DateTime m = DateTime(widget.today.year, widget.today.month);

  @override
  Widget build(BuildContext context) {
    final today = widget.today;
    final shown = widget.state.shown;
    final evs = <int, List<Program>>{};
    final moved = <Program>[];
    for (final p in shown) {
      final e = effectiveDate(m.year, m.month, p.day);
      evs.putIfAbsent(e.day, () => []).add(p);
      if (wasMoved(m.year, m.month, p.day)) moved.add(p);
    }
    final rows = evs.keys.toList()..sort();
    final lead = m.weekday % 7; // الأحد = 0
    final days = DateUtils.getDaysInMonth(m.year, m.month);
    const heads = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox(),
      for (var d = 1; d <= days; d++) _cell(DateTime(m.year, m.month, d), evs[d], today),
    ];
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Row(children: [
          IconButton.outlined(
              tooltip: 'الشهر السابق',
              onPressed: () => setState(() => m = DateTime(m.year, m.month - 1)),
              icon: const Icon(Icons.chevron_right)),
          Expanded(
              child: Column(children: [
            Text('${monthAr[m.month - 1]} ${m.year}',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink)),
            Text('${hijriText(DateTime(m.year, m.month, 1))}  ←  ${hijriText(DateTime(m.year, m.month, days))}',
                style: const TextStyle(fontSize: 11, color: muted)),
          ])),
          IconButton.outlined(
              tooltip: 'الشهر التالي',
              onPressed: () => setState(() => m = DateTime(m.year, m.month + 1)),
              icon: const Icon(Icons.chevron_left)),
        ]),
      ),
      Card1(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(children: [
          Row(children: [
            for (final h in heads)
              Expanded(child: Center(child: Text(h, style: const TextStyle(fontSize: 12, color: muted)))),
          ]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 0.85,
            children: cells,
          ),
          const SizedBox(height: 10),
          const Wrap(spacing: 14, runSpacing: 6, children: [
            _Key(ink, 'موعد قادم'),
            _Key(Color(0xFFC9D2E3), 'صُرف'),
            _Key(Color(0xFFE3E8F0), 'نهاية الأسبوع'),
          ]),
        ]),
      ),
      if (moved.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: warnBg, borderRadius: BorderRadius.circular(14)),
          child: Text(
              'انتقل ${moved.length == 1 ? 'موعد' : '${moved.length} مواعيد'} هذا الشهر لأنها وقعت في نهاية الأسبوع: '
              '${moved.map((p) => '${p.name} (${p.day} ← ${effectiveDate(m.year, m.month, p.day).day})').join('، ')}.',
              style: const TextStyle(color: Color(0xFF5C3408), height: 1.6)),
        ),
      const Padding(padding: EdgeInsets.fromLTRB(20, 6, 20, 8), child: Text('مواعيد الشهر', style: h2)),
      Card1(
        child: Column(children: [
          for (final d in rows)
            for (final p in evs[d]!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => widget.onOpen(p),
                leading: Text('$d', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(weekdayAr[DateTime(m.year, m.month, d).weekday]! +
                    (wasMoved(m.year, m.month, p.day) ? ' · أُخّر من ${p.day}' : '')),
                trailing: DateTime(m.year, m.month, d).isBefore(DateTime(today.year, today.month, today.day))
                    ? const Text('صُرف', style: TextStyle(color: muted))
                    : Text(leftText(daysUntil(today, DateTime(m.year, m.month, d))),
                        style: const TextStyle(color: warnFg, fontWeight: FontWeight.w700)),
              ),
        ]),
      ),
    ]);
  }

  Widget _cell(DateTime d, List<Program>? ev, DateTime today) {
    final isToday = DateUtils.isSameDay(d, today);
    final weekend = d.weekday == DateTime.friday || d.weekday == DateTime.saturday;
    final past = d.isBefore(DateTime(today.year, today.month, today.day));
    var bg = weekend ? const Color(0xFFE3E8F0) : const Color(0xFFF7F9FC);
    var fg = ink;
    if (ev != null) {
      bg = past ? const Color(0xFFC9D2E3) : ink;
      fg = past ? ink : Colors.white;
    }
    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: isToday ? Border.all(color: const Color(0xFFC9771B), width: 2) : null),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
        if (ev != null)
          Text(ev.length > 1 ? '${ev.length}+' : ev.first.name.split(' ').last,
              maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 9, color: fg)),
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  final Color c;
  final String t;
  const _Key(this.c, this.t);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 12, color: muted)),
      ]);
}
