import 'package:flutter/material.dart';
import '../core/settings.dart';
import '../main.dart';
import '../model/programs.dart';
import 'common.dart';

class SettingsPage extends StatelessWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});

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
