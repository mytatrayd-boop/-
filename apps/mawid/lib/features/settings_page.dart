import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/ics.dart';
import '../core/payout_rules.dart';
import '../core/settings.dart';
import '../main.dart';
import '../model/programs.dart';
import 'common.dart';

class SettingsPage extends StatelessWidget {
  final AppState state;
  final DateTime? today;
  const SettingsPage({super.key, required this.state, this.today});

  Future<void> _exportAll() async {
    final now = today ?? DateTime.now();
    final evs = <IcsEvent>[];
    for (var k = 0; k < 12; k++) {
      final m = DateTime(now.year, now.month + k, 1);
      for (final p in state.shown) {
        final e = effectiveDate(m.year, m.month, p.day);
        if (!e.isBefore(DateTime(now.year, now.month, now.day))) {
          evs.add(IcsEvent('${p.id}-${e.year}${e.month}${e.day}', p.name, e));
        }
      }
    }
    for (final o in occasions) {
      evs.add(IcsEvent('occ-${o.month}-${o.day}', o.name, nextAnnual(now, o.month, o.day)));
    }
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(Uint8List.fromList(utf8.encode(buildIcs(evs))), mimeType: 'text/calendar', name: 'mawid.ics')],
    ));
  }

  @override
  Widget build(BuildContext context) => ListView(children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text('تخصيص', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink))),
        const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('اختر المواعيد التي تهمك. المخفية لا تظهر في أي شاشة.', style: TextStyle(color: muted))),
        Card1(
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('التنبيهات'),
              subtitle: const Text('الساعة 9 صباحاً حسب خيارات «ذكّرني» في كل موعد'),
              value: state.notificationsOn,
              onChanged: state.setNotificationsOn,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إضافة كل المواعيد إلى التقويم'),
              subtitle: const Text('12 شهراً والمناسبات الوطنية'),
              trailing: const Icon(Icons.event_available_outlined),
              onTap: _exportAll,
            ),
          ]),
        ),
        Card1(
          child: Column(children: [
            for (final p in programs)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text('يوم ${p.day} من كل شهر'),
                value: state.visible(p),
                onChanged: (v) => state.setVisible(p.id, v),
              ),
          ]),
        ),
      ]);
}
