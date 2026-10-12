/// هوية العميل المرسلة إلى الخادم في `X-Client` (ARCHITECTURE §8.1). Dart صافٍ.
library;

/// رقم البناء، يطابق ما بعد `+` في `version` في pubspec.yaml (اختبار يتحقق).
/// الخادم يرفض ما دون `MIN_CLIENT` بـ 426.
const clientBuildNumber = 1;

/// `adeeb-android/<build>` أو `adeeb-ios/<build>`.
String clientHeader({required bool ios}) =>
    'adeeb-${ios ? 'ios' : 'android'}/$clientBuildNumber';
