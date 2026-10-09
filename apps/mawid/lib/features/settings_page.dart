import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/ics.dart';
import '../core/payout_rules.dart';
import '../core/widget_sync.dart';
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
        Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text('تخصيص', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink))),
        const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('اختر المواعيد التي تهمك. المخفية لا تظهر في أي شاشة.', style: TextStyle(color: muted))),
        Card1(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('لون التطبيق', style: h2),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 10, children: [
              for (var i = 0; i < accents.length; i++)
                Semantics(
                  button: true,
                  selected: state.accentIndex == i,
                  label: 'لون ${accents[i].name}',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => state.setAccent(i),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accents[i].ink,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: state.accentIndex == i ? const Color(0xFFC9771B) : line,
                            width: state.accentIndex == i ? 3 : 1),
                      ),
                      child: state.accentIndex == i ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  ),
                ),
            ]),
          ]),
        ),
        Card1(
          child: Builder(builder: (context) {
            final ids = state.widgetIds;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ودجت الشاشة الرئيسية', style: h2),
              const SizedBox(height: 4),
              const Text('يعرض المتبقي إلى موعد الصرف للمواعيد التي تختارها (حتى 4). يتحدث يومياً.',
                  style: TextStyle(color: muted, fontSize: 13)),
              for (final p in state.shown)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: ids.contains(p.id),
                  onChanged: (ids.contains(p.id) || ids.length < 4) ? (_) => state.toggleWidgetId(p.id) : null,
                  title: Text(p.name),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.widgets_outlined),
                  label: const Text('إضافة الودجت إلى الشاشة الرئيسية'),
                  onPressed: () async {
                    final ok = await pinWidget();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('من الشاشة الرئيسية: اضغط مطولاً ← الودجت ← موعد')));
                    }
                  },
                ),
              ),
            ]);
          }),
        ),
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
