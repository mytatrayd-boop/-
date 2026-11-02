# إعلان «الخدمة الأمامية» (Google Play) وبيانات الموقع

مطلوب في Play Console قبل رفع أي نسخة فيها «أنا هنا» (إذن `FOREGROUND_SERVICE_LOCATION`):
**Policy ← App content ← Foreground service permissions**.

## الإعلان
- النوع: **Location**.
- الوصف (English):
  > Family trip feature "أنا هنا": a parent starts a trip, and each family member taps "I'm here" to share their live location with their own family circle only, so parents can find children and elderly relatives in crowded places such as the Haram (Makkah and Madinah), shopping malls, and crowded open areas such as parks, markets and events. The foreground service of type location keeps running with the screen off; a persistent notification is shown while sharing, and it stops when the trip ends. Locations are deleted at the end of the trip.
- الفيديو (رابط YouTube غير مدرج، 30–60 ثانية) يُظهر بالترتيب:
  1. المسؤول يبدأ رحلة.
  2. فرد يضغط «أنا هنا» ويوافق على إذن الموقع (الدقيق).
  3. ظهور إشعار «أسرتي — أنا هنا: تشارك مكانك مع أسرتك».
  4. قفل الشاشة، ثم ظهور حركة الفرد على خريطة المسؤول.
  5. المسؤول ينهي الرحلة فيختفي الإشعار.

## Data safety (Play Console ← App content ← Data safety)
- Location: **Precise location** — Collected, shared only within the user's own family circle (no third parties), optional (user taps "I'm here"), purpose: App functionality. Deleted at trip end.
- Privacy policy URL: صفحة `privacy` (محدَّثة بتاريخ 2 نوفمبر 2026 بفقرة الموقع).

## App Store (آبل)
- Privacy nutrition label: **Precise Location**، مرتبط بالهوية، للاستخدام داخل التطبيق فقط، لا تتبع (Tracking = No).
- `UIBackgroundModes: location`: يلزم نص في ملاحظات المراجعة (انظر `APP_REVIEW_REPLY.md`، قسم الموقع).
