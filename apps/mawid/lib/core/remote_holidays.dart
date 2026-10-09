import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/holidays.dart';

const holidaysUrl =
    'https://raw.githubusercontent.com/mytatrayd-boop/-/claude/mobile-app-design-gxh65v/apps/mawid/remote/holidays.json';
const _key = 'holidays_cache';

/// آخر نسخة محفوظة على الجوال (أو فارغة).
List<Holiday> cachedHolidays(SharedPreferences p) {
  final s = p.getString(_key);
  if (s == null) return const [];
  try {
    return parseExtra(s);
  } catch (_) {
    return const [];
  }
}

/// يجلب الملف ويحفظه فقط إذا كان صالحاً. يرجع القائمة الجديدة أو null عند الفشل.
Future<List<Holiday>?> refreshHolidays(SharedPreferences p, http.Client c,
    {String url = holidaysUrl}) async {
  try {
    final r = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final list = parseExtra(r.body); // يرمي إذا غير صالح فلا نكتب فوق النسخة الجيدة
    await p.setString(_key, r.body);
    return list;
  } catch (_) {
    return null;
  }
}
