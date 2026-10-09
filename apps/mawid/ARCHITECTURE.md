# ARCHITECTURE — موعد
- Flutter (iOS+Android)، Riverpod، حفظ محلي shared_preferences، تنبيهات flutter_local_notifications، مشاركة share_plus، إضافة للتقويم add_2_calendar.
- لا خادم في MVP. تأكيد الصرف لاحقاً عبر Firebase.
- `lib/core/payout_rules.dart`: دالة نقية تحسب الموعد الفعلي (قلب المنطق، تُختبر بالكامل).
- `lib/core/hijri.dart`: جدول أم القرى مدمج.
- `assets/data/programs.json` و`holidays.json`: بيانات قابلة للتحديث بدون تغيير الكود.
- المجلدات: core، features/{home,month,detail,year,settings}، data، l10n.
- الاختبارات: وحدات لقاعدة الصرف (كل أيام الأسبوع، السنوات الكبيسة)، وwidget لكل شاشة.
