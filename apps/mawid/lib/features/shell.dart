import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../core/settings.dart';
import '../main.dart';
import '../model/holidays.dart';
import '../model/programs.dart';
import 'budget.dart';
import 'detail.dart';
import 'home.dart';
import 'month.dart';
import 'settings_page.dart';

class Shell extends StatefulWidget {
  final AppState state;
  final DateTime today;
  final ValueListenable<List<Holiday>> extra;
  const Shell({super.key, required this.state, required this.today, required this.extra});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  void openDetail(Program p) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailPage(p: p, state: widget.state, today: widget.today)));

  @override
  Widget build(BuildContext context) {
    final s = widget.state, t = widget.today;
    final pages = [
      HomePage(state: s, today: t, onOpen: openDetail),
      MonthPage(state: s, today: t, extra: widget.extra.value, onOpen: openDetail),
      BudgetPage(state: s, today: t),
      SettingsPage(state: s),
    ];
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) => ValueListenableBuilder<List<Holiday>>(
        valueListenable: widget.extra,
        builder: (_, _, _) => Scaffold(
        body: SafeArea(child: pages[tab]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          backgroundColor: Colors.white,
          indicatorColor: ground,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: 'الشهر'),
            NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'الميزانية'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'تخصيص'),
          ],
        ),
      ),
      ),
    );
  }
}
