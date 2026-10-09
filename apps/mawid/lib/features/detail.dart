import 'package:flutter/material.dart';
import '../core/payout_rules.dart';
import '../core/settings.dart';
import '../main.dart';
import '../model/programs.dart';
import 'common.dart';

class DetailPage extends StatefulWidget {
  final Program p;
  final AppState state;
  final DateTime today;
  const DetailPage({super.key, required this.p, required this.state, required this.today});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final newTask = TextEditingController();

  @override
  void dispose() {
    newTask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p, s = widget.state;
    final d = nextPayout(widget.today, p.day);
    final n = daysUntil(widget.today, d);
    return Scaffold(
      body: ListenableBuilder(
        listenable: s,
        builder: (_, _) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 40, 20, 22),
            decoration: const BoxDecoration(
                color: ink, borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))),
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconButton(
                  tooltip: 'رجوع',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_forward, color: Colors.white)),
              Row(children: [
                const SizedBox(width: 8),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  Text('${dateText(d)} · ${hijriText(d)}',
                      style: const TextStyle(color: Color(0xFFC9D2E3), fontSize: 13)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Text('$n', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: ink, height: 1)),
                    const Text('يوم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
                  ]),
                ),
              ]),
            ]),
          ),
          Card1(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ذكّرني', style: h2),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final r in const {'d3': 'قبل 3 أيام', 'd1': 'قبل 24 ساعة', 'd0': 'عند النزول'}.entries)
                FilterChip(
                  label: Text(r.value),
                  selected: s.reminder(r.key),
                  onSelected: (v) => s.setReminder(r.key, v),
                ),
            ]),
          ])),
          Card1(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مهام عند النزول', style: h2),
            for (final t in s.tasks(p.id))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: s.done(p.id).contains(t),
                onChanged: (_) => s.toggleTask(p.id, t),
                title: Text(t),
              ),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: newTask,
                      decoration: const InputDecoration(hintText: 'أضف مهمة', isDense: true, border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: () {
                    final t = newTask.text.trim();
                    if (t.isEmpty) return;
                    s.addTask(p.id, t);
                    newTask.clear();
                  },
                  child: const Text('إضافة')),
            ]),
          ])),
          SplitCard(state: s),
        ]),
      ),
    );
  }
}

const splitNames = ['ادخار', 'فواتير', 'إيجار', 'مصروف'];
const splitColors = [Color(0xFF1C2B4B), Color(0xFF4A6491), Color(0xFF9DB0D0), Color(0xFFE39B45)];

class SplitCard extends StatefulWidget {
  final AppState state;
  const SplitCard({super.key, required this.state});
  @override
  State<SplitCard> createState() => _SplitCardState();
}

class _SplitCardState extends State<SplitCard> {
  final amount = TextEditingController();
  bool editing = false;
  late List<double> draft = widget.state.split.map((e) => e.toDouble()).toList();

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = editing ? draft.map((e) => e.round()).toList() : widget.state.split;
    final total = double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
    final sum = sp.fold<int>(0, (a, b) => a + b);
    return Card1(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('تقسيم المبلغ', style: h2),
      TextField(
        controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'المبلغ المتوقع (ريال)'),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(flex: sp[i] == 0 ? 0 : sp[i], child: Container(height: 14, color: splitColors[i])),
        ]),
      ),
      const SizedBox(height: 10),
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(children: [
            Row(children: [
              Container(width: 10, height: 10, color: splitColors[i]),
              const SizedBox(width: 6),
              Text('${splitNames[i]} ${sp[i]}%'),
              const Spacer(),
              if (total > 0) Text((total * sp[i] / 100).toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            if (editing)
              Slider(
                value: draft[i],
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => draft[i] = v),
              ),
          ]),
        ),
      if (editing && sum != 100)
        Text('المجموع $sum% ويجب أن يكون 100%', style: const TextStyle(color: Color(0xFFB3261E))),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: editing && sum != 100
              ? null
              : () async {
                  if (editing) await widget.state.setSplit(sp);
                  setState(() {
                    editing = !editing;
                    draft = widget.state.split.map((e) => e.toDouble()).toList();
                  });
                },
          child: Text(editing ? 'حفظ النسب' : 'تعديل النسب'),
        ),
      ),
    ]));
  }
}
