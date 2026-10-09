import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/programs.dart';

class Accent {
  final String name;
  final Color ink, ground;
  const Accent(this.name, this.ink, this.ground);
}

/// ألوان مختارة كلها داكنة بما يكفي لنص أبيض (تباين ≥ 4.5).
const accents = <Accent>[
  Accent('كحلي', Color(0xFF1C2B4B), Color(0xFFEEF1F6)),
  Accent('أخضر', Color(0xFF0E4D3A), Color(0xFFE9EEEA)),
  Accent('عنابي', Color(0xFF5A1F2B), Color(0xFFF3EDEE)),
  Accent('بنفسجي', Color(0xFF45286B), Color(0xFFF0EDF5)),
  Accent('تركواز', Color(0xFF0B5560), Color(0xFFE8F0F1)),
  Accent('فحمي', Color(0xFF2B2F36), Color(0xFFEFEFF0)),
];

/// حالة محلية بسيطة تُحفظ على الجوال.
class AppState extends ChangeNotifier {
  final SharedPreferences _p;
  AppState(this._p);

  Set<String> get hidden => (_p.getStringList('hidden') ?? []).toSet();
  bool visible(Program x) => !hidden.contains(x.id);
  List<Program> get shown => programs.where(visible).toList();

  Future<void> setVisible(String id, bool v) async {
    final h = hidden;
    v ? h.remove(id) : h.add(id);
    await _p.setStringList('hidden', h.toList());
    notifyListeners();
  }

  /// برامج الودجت (حتى 4).
  List<String> get widgetIds => _p.getStringList('widget_ids') ?? ['citizen', 'gov'];
  Future<void> toggleWidgetId(String id) async {
    final l = widgetIds;
    if (l.contains(id)) {
      l.remove(id);
    } else if (l.length < 4) {
      l.add(id);
    }
    await _p.setStringList('widget_ids', l);
    notifyListeners();
  }

  int get accentIndex => _p.getInt('accent') ?? 0;
  Future<void> setAccent(int i) async {
    await _p.setInt('accent', i);
    notifyListeners();
  }

  bool get notificationsOn => _p.getBool('notif') ?? true;
  Future<void> setNotificationsOn(bool v) async {
    await _p.setBool('notif', v);
    notifyListeners();
  }

  // تذكيرات: d3 / d1 / d0
  bool reminder(String k) => _p.getBool('rem_$k') ?? (k != 'd0');
  Future<void> setReminder(String k, bool v) async {
    await _p.setBool('rem_$k', v);
    notifyListeners();
  }

  List<String> tasks(String id) => _p.getStringList('tasks_$id') ?? [];
  Set<String> done(String id) => (_p.getStringList('done_$id') ?? []).toSet();
  Future<void> addTask(String id, String t) async {
    await _p.setStringList('tasks_$id', [...tasks(id), t]);
    notifyListeners();
  }

  Future<void> toggleTask(String id, String t) async {
    final d = done(id);
    d.contains(t) ? d.remove(t) : d.add(t);
    await _p.setStringList('done_$id', d.toList());
    notifyListeners();
  }

  // تقسيم المبلغ: ادخار، فواتير، إيجار، مصروف (مجموعها 100)
  List<int> get split {
    final s = _p.getStringList('split');
    return s == null ? [20, 30, 30, 20] : s.map(int.parse).toList();
  }

  Future<void> setSplit(List<int> v) async {
    await _p.setStringList('split', v.map((e) => '$e').toList());
    notifyListeners();
  }
}
