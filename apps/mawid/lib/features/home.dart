import 'package:flutter/material.dart';
import '../core/payout_rules.dart';
import '../core/settings.dart';
import '../main.dart';
import '../model/programs.dart';
import 'common.dart';

class HomePage extends StatelessWidget {
  final AppState state;
  final DateTime today;
  final void Function(Program) onOpen;
  const HomePage({super.key, required this.state, required this.today, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final items = state.shown
        .map((p) => (p: p, d: nextPayout(today, p.day)))
        .toList()
      ..sort((a, b) => a.d.compareTo(b.d));
    final occ = occasions
        .map((o) => (o: o, d: nextAnnual(today, o.month, o.day)))
        .toList()
      ..sort((a, b) => a.d.compareTo(b.d));
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('موعد', style: TextStyle(fontFamily: 'Lalezar', fontSize: 36, color: ink)),
          const Spacer(),
          Flexible(
            child: Text('${dateText(today)}\n${hijriText(today)}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 13, color: muted, height: 1.5)),
          ),
        ]),
      ),
      if (items.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Text('كل البرامج مخفية. فعّلها من «تخصيص».'))
      else ...[
        _Hero(item: items.first, today: today, onTap: () => onOpen(items.first.p)),
        Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 10),
            child: Text('الأوراق القادمة', style: h2)),
        SizedBox(
          height: 144,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final i in items.skip(1))
                GestureDetector(
                  onTap: () => onOpen(i.p),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsetsDirectional.only(end: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: line)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 6, color: ink),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${i.d.day}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
                          Text('${monthAr[i.d.month - 1]} · ${weekdayAr[i.d.weekday]}',
                              style: const TextStyle(fontSize: 11, color: muted)),
                          const SizedBox(height: 4),
                          Text(i.p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
      Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Text('المناسبات الوطنية', style: h2)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          for (final o in occ)
            Expanded(
              child: Container(
                margin: const EdgeInsetsDirectional.only(end: 10),
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: ink, width: 3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${daysUntil(today, o.d)} يوماً',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(o.o.name, style: const TextStyle(fontSize: 13, color: muted)),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _Hero extends StatelessWidget {
  final ({Program p, DateTime d}) item;
  final DateTime today;
  final VoidCallback onTap;
  const _Hero({required this.item, required this.today, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = item.d, p = item.p;
    final moved = wasMoved(d.year, d.month, p.day);
    final nominal = DateTime(d.year, d.month, p.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Semantics(
        button: true,
        label: '${p.name}، ${dateText(d)}، ${leftText(daysUntil(today, d))}',
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(14)),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 14), spreadRadius: -16)]),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${monthAr[d.month - 1]} ${d.year}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  Flexible(child: Text(hijriText(d), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(children: [
                  Text(weekdayAr[d.weekday]!, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  Text('${d.day}', style: TextStyle(fontFamily: 'Lalezar', fontSize: 120, height: 1.1, color: ink)),
                  const Divider(height: 28, color: line),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                    Pill(leftText(daysUntil(today, d))),
                  ]),
                  if (moved)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            'أُخّر من ${weekdayAr[nominal.weekday]} ${nominal.day} ${monthAr[nominal.month - 1]} بسبب نهاية الأسبوع',
                            style: const TextStyle(fontSize: 13, color: muted)),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
