/// متى يتحقق التطبيق من تحديث البيانات (ARCHITECTURE §16.2، D21). Dart صافٍ.
library;

/// بعد تحقق ناجح.
const checkIntervalAfterSuccess = Duration(days: 7);

/// بعد محاولة فاشلة (بلا إنترنت، خطأ خادم، حزمة مرفوضة...).
const checkIntervalAfterFailure = Duration(hours: 24);

/// هل يحين التحقق الآن؟ يُسأل عند فتح التطبيق والعودة للواجهة فقط (لا مهام
/// خلفية).
///
/// - لا تحقق أثناء الإعداد الأولي ([onboardingDone] = false).
/// - لم يُحاوَل قط ← نعم.
/// - آخر محاولة فاشلة (أحدث من آخر نجاح) ← بعد 24 ساعة منها.
/// - وإلا ← بعد 7 أيام من آخر نجاح.
/// - ساعة الجهاز رجعت قبل آخر وقت مسجّل ← نعم (وإلا يتوقف التحقق حتى تلحق).
bool isCheckDue({
  required DateTime now,
  required DateTime? lastCheckOk,
  required DateTime? lastAttempt,
  required bool onboardingDone,
}) {
  if (!onboardingDone) return false;
  if (lastAttempt == null && lastCheckOk == null) return true;
  final failedLast =
      lastAttempt != null &&
      (lastCheckOk == null || lastAttempt.isAfter(lastCheckOk));
  final since = failedLast ? lastAttempt : lastCheckOk!;
  final elapsed = now.difference(since);
  if (elapsed.isNegative) return true;
  return elapsed >=
      (failedLast ? checkIntervalAfterFailure : checkIntervalAfterSuccess);
}
