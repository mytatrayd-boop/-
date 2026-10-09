import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../model/programs.dart';
import 'payout_rules.dart';
import 'settings.dart';

const widgetProvider = 'com.mytatrayd.mawid.MawidWidgetProvider';

String _d(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// ما يقرأه الودجت الأصلي: لكل موعد مختار قائمة تواريخه الفعلية القادمة (14 شهراً)،
/// فيحسب الودجت المتبقي بنفسه كل يوم بدون فتح التطبيق.
Map<String, dynamic> buildWidgetPayload(DateTime now, List<Program> ps, Set<String> ids, int colorValue) {
  final today = DateTime(now.year, now.month, now.day);
  final items = <Map<String, dynamic>>[];
  for (final p in ps.where((p) => ids.contains(p.id))) {
    final dates = <String>[];
    for (var k = 0; k < 14; k++) {
      final m = DateTime(today.year, today.month + k, 1);
      final e = effectiveDate(m.year, m.month, p.day);
      if (!e.isBefore(today)) dates.add(_d(e));
    }
    items.add({'name': p.name, 'dates': dates});
  }
  return {'color': colorValue, 'items': items};
}

/// غلاف رفيع على المكتبة؛ المنطق في buildWidgetPayload (مختبَر).
Future<void> syncWidget(AppState s, DateTime now) async {
  try {
    final ps = s.shown;
    final ids = s.widgetIds.toSet();
    final color = accents[s.accentIndex.clamp(0, accents.length - 1)].ink.toARGB32();
    await HomeWidget.saveWidgetData<String>('payload', jsonEncode(buildWidgetPayload(now, ps, ids, color)));
    await HomeWidget.updateWidget(qualifiedAndroidName: widgetProvider);
  } catch (_) {
    // منصة بلا ودجت (آيفون حالياً/اختبارات): نتجاهل
  }
}

Future<bool> pinWidget() async {
  try {
    if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: widgetProvider);
    return true;
  } catch (_) {
    return false;
  }
}
