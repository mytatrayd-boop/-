/// متى يتحقق التطبيق من تحديث البيانات (ARCHITECTURE §16.2، D21). Dart صافٍ.
library;

/// بعد تحقق ناجح.
const checkIntervalAfterSuccess = Duration(days: 7);

/// بعد محاولة فاشلة (بلا إنترنت، خطأ خادم، حزمة مرفوضة...).
const checkIntervalAfterFailure = Duration(hours: 24);

/// هل يحين التحقق الآن؟ يُسأل عند فتح التطبيق والعودة للواجهة فقط (لا مهام
/// خلفية).
///
/// - مفتاح «تحديث البيانات تلقائياً» مطفأ ([autoUpdate] = false) ← لا أبداً
///   (زر «تحقق الآن» طلب صريح لا يمر من هنا، DESIGN 8.7).
/// - لا تحقق أثناء الإعداد الأولي ([onboardingDone] = false).
/// - لم يُحاوَل قط ← نعم.
/// - آخر محاولة فاشلة (أحدث من آخر نجاح) ← بعد 24 ساعة منها.
/// - وإلا ← بعد 7 أيام من آخر نجاح.
/// - وقت مسجّل في المستقبل (ساعة الجهاز رجعت للخلف) يُعامل كأنه الآن، فلا
///   يصير التحقق مستحقاً في كل عودة للواجهة. ومعه `UpdateState.clampFuture` يُعيد
///   المستدعي كتابة الوقت المسجّل إلى الآن، فتبدأ المهلة من جديد ولا يتوقف
///   التحقق حتى تلحق الساعة.
bool isCheckDue({
  required DateTime now,
  required DateTime? lastCheckOk,
  required DateTime? lastAttempt,
  required bool onboardingDone,
  bool autoUpdate = true,
}) {
  if (!autoUpdate || !onboardingDone) return false;
  if (lastAttempt == null && lastCheckOk == null) return true;
  final failedLast =
      lastAttempt != null &&
      (lastCheckOk == null || lastAttempt.isAfter(lastCheckOk));
  final recorded = failedLast ? lastAttempt : lastCheckOk!;
  final since = recorded.isAfter(now) ? now : recorded;
  final elapsed = now.difference(since);
  return elapsed >=
      (failedLast ? checkIntervalAfterFailure : checkIntervalAfterSuccess);
}
