import 'package:flutter/material.dart';
import '../core/payout_rules.dart';
import '../core/settings.dart';
import '../main.dart';
import '../model/programs.dart';
import 'common.dart';
import 'detail.dart';

class BudgetPage extends StatefulWidget {
  final AppState state;
  final DateTime today;
  const BudgetPage({super.key, required this.state, required this.today});
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  late int year = widget.today.year;

  @override
  Widget build(BuildContext context) {
    final shown = widget.state.shown;
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Text('الميزانية', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink))),
      MonthChart(state: widget.state, today: widget.today),
      SplitCard(state: widget.state),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(children: [
          IconButton.outlined(
              tooltip: 'السنة السابقة', onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_right)),
          Expanded(child: Center(child: Text('جدول $year', style: h2))),
          IconButton.outlined(
              tooltip: 'السنة التالية', onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_left)),
        ]),
      ),
      Card1(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            columns: [
              const DataColumn(label: Text('الشهر')),
              for (final p in shown) DataColumn(label: Text(p.name.split(' ').last)),
            ],
            rows: [
              for (var m = 1; m <= 12; m++)
                DataRow(cells: [
                  DataCell(Text(monthAr[m - 1])),
                  for (final p in shown)
                    DataCell(Builder(builder: (_) {
                      final e = effectiveDate(year, m, p.day);
                      final mv = wasMoved(year, m, p.day);
                      return Text('${e.day}${mv ? ' ←${p.day}' : ''}',
                          style: TextStyle(fontWeight: mv ? FontWeight.w700 : FontWeight.w400, color: mv ? warnFg : ink));
                    })),
                ]),
            ],
          ),
        ),
      ),
    ]);
  }
}

/// توزيع مواعيد الشهر الحالي على أيامه: عمود لكل يوم فيه صرف، وارتفاعه بعدد المواعيد.
class MonthChart extends StatelessWidget {
  final AppState state;
  final DateTime today;
  const MonthChart({super.key, required this.state, required this.today});

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(today.year, today.month);
    final count = List<int>.filled(days + 1, 0);
    final names = <int, List<String>>{};
    for (final p in state.shown) {
      final e = effectiveDate(today.year, today.month, p.day);
      count[e.day]++;
      names.putIfAbsent(e.day, () => []).add(p.name);
    }
    final days1 = [for (var d = 1; d <= days; d++) if (count[d] > 0) d];
    final summary = days1.isEmpty
        ? 'لا مواعيد هذا الشهر'
        : days1.map((d) => '$d: ${names[d]!.join('، ')}').join(' — ');
    final gaps = <int>[];
    for (var i = 1; i < days1.length; i++) {
      gaps.add(days1[i] - days1[i - 1]);
    }
    final maxGap = gaps.isEmpty ? 0 : gaps.reduce((a, b) => a > b ? a : b);
    return Card1(
      child: Semantics(
        label: 'توزيع مواعيد ${monthAr[today.month - 1]}: $summary',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('توزيع ${monthAr[today.month - 1]}', style: h2),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var d = 1; d <= days; d++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: count[d] == 0 ? 3 : 14.0 + count[d] * 20,
                    decoration: BoxDecoration(
                      color: count[d] == 0 ? line : ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Row(children: [
            for (var d = 1; d <= days; d++)
              Expanded(
                child: Center(
                  child: Text(d == 1 || d % 5 == 0 ? '$d' : '',
                      style: const TextStyle(fontSize: 9, color: muted)),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text(
              maxGap > 0
                  ? 'أطول فاصل بين موعدين: $maxGap يوماً'
                  : (days1.isEmpty ? 'لا مواعيد هذا الشهر' : 'موعد واحد هذا الشهر'),
              style: const TextStyle(color: muted, fontSize: 13)),
        ]),
      ),
    );
  }
}
