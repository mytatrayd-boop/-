import 'package:flutter/material.dart';
import '../main.dart';
import '../model/programs.dart';
import 'common.dart';

/// Programs grouped by their official website, e.g. «الضمان الاجتماعي المطور والتأهيل الشامل».
List<(String, String, String)> groupedSources() {
  final byUrl = <String, List<Program>>{};
  for (final p in programs) {
    byUrl.putIfAbsent(p.sourceUrl, () => []).add(p);
  }
  return [
    for (final e in byUrl.entries)
      (e.value.map((p) => p.name).join(' و'), e.value.first.source, e.key),
  ];
}

/// «المصادر الرسمية»: every government date in the app links to its official source
/// (Google Play misleading-claims policy).
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المصادر الرسمية')),
        body: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
                'المواعيد في التطبيق محسوبة من قواعد الصرف المعلنة. المرجع الوحيد هو الجهة الرسمية؛ تحقّق منها قبل أي قرار مالي.',
                style: TextStyle(color: muted, height: 1.6)),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text('مواعيد الصرف', style: h2)),
          Card1(
            child: Column(children: [
              for (final (names, source, url) in groupedSources()) SourceLink('$names: $source', url),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text('الإجازات', style: h2)),
          Card1(
            child: Column(children: [
              for (final (label, url) in holidaySources) SourceLink(label, url),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
                'تطبيق مستقل غير تابع لأي جهة حكومية، ولا يمثّل أياً منها، ولا يصرف أي مبالغ. المواعيد قد تتغير بقرار من الجهة المختصة.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.6)),
          ),
        ]),
      );
}
