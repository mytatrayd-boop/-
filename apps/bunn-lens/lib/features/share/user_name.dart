import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const userNamePrefsKey = 'user_signature_name';
const userNameMaxLength = 40;

/// يقلّم الاسم ويوحّد المسافات ويقصّه إلى [userNameMaxLength] حرفاً. الفارغ يعني «لا اسم».
String normalizeUserName(String? raw) {
  final collapsed = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  final runes = collapsed.runes.toList();
  if (runes.length <= userNameMaxLength) return collapsed;
  return String.fromCharCodes(runes.take(userNameMaxLength)).trim();
}

/// منطق منع المشاركة بلا اسم: يعيد الاسم الصالح للتوقيع، أو null إن لم يُكتب (إلغاء/فارغ).
/// إن كان [current] فارغاً يستدعي [ask] ثم [save] بالاسم الجديد.
Future<String?> ensureUserName({
  required String current,
  required Future<String?> Function() ask,
  required Future<void> Function(String name) save,
}) async {
  final existing = normalizeUserName(current);
  if (existing.isNotEmpty) return existing;
  final entered = normalizeUserName(await ask());
  if (entered.isEmpty) return null;
  await save(entered);
  return entered;
}

/// اسم المستخدم للتوقيع، محفوظ محلياً (shared_preferences). الفراغ = لم يُكتب بعد.
class UserNameNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return normalizeUserName(prefs.getString(userNamePrefsKey));
    } catch (_) {
      // التخزين غير متاح: نعامله كاسم فارغ فيُطلب من المستخدم كتابته.
      return '';
    }
  }

  Future<void> setName(String raw) async {
    final name = normalizeUserName(raw);
    final prefs = await SharedPreferences.getInstance();
    if (name.isEmpty) {
      await prefs.remove(userNamePrefsKey);
    } else {
      await prefs.setString(userNamePrefsKey, name);
    }
    state = AsyncData(name);
  }
}

final userNameProvider = AsyncNotifierProvider<UserNameNotifier, String>(UserNameNotifier.new);
