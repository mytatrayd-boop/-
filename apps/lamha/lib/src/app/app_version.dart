/// رقم نسخة التطبيق للعرض في الإعدادات (يتحقق test/app/app_version_test.dart أن الاسم يطابق pubspec.yaml).
/// رقم البناء يُمرَّر وقت البناء من CI: `--dart-define=APP_BUILD=<رقم التشغيل>` (وهو نفسه versionCode في Google Play
/// وbuild number في TestFlight)؛ وفي البناء المحلي يغيب فيُعرض الاسم وحده.
const appVersionName = '1.1.0';
const appBuildNumber = String.fromEnvironment('APP_BUILD');

String appVersionText() => appBuildNumber.isEmpty ? appVersionName : '$appVersionName ($appBuildNumber)';
