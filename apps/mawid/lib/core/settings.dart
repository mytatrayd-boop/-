import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/programs.dart';

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
