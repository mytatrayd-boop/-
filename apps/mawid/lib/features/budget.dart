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
      const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Text('الميزانية', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink))),
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
