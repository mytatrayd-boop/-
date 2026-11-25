import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../domain/app_languages.dart';

/// لغة الواجهة المختارة. null = لغة الجهاز (والعربية إن لم تُدعم).
/// القيمة الأولية تُقرأ من التخزين عند الإقلاع (main) فلا وميض لغة خاطئة.
final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final code = validLanguageCode(ref.read(initialLanguageCodeProvider));
    return code == null ? null : Locale(code);
  }

  /// يطبّق فوراً ثم يحفظ. فشل الحفظ لا يمنع التطبيق (يعود الاختيار للافتراضي بعد إعادة التشغيل).
  Future<void> setLanguage(String code) async {
    final valid = validLanguageCode(code);
    if (valid == null) return;
    state = Locale(valid);
    try {
      await ref.read(localeStoreProvider).save(valid);
    } catch (e) {
      debugPrint('language save failed: ${e.runtimeType}');
    }
  }
}
