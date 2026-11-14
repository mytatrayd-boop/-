# CLAUDE.md — رحلة (rihla)

يرث قواعد /home/user/-/CLAUDE.md (عربي ومختصر، لا إجراء نهائي بدون موافقة المالك، لا كلمات مرور، لا تقل "يعمل" قبل الاختبار).

## التطبيق
تطبيق أفقي يقسم الشاشة: كاميرا + خريطة مسار. ينتج فيديو 16:9 مزدوجاً يُحفظ في معرض الجوال، ويحفظ المسار محلياً للمشاركة برابط خرائط جوجل (نقاط قليلة) وملف GPX. مجاني، بلا حساب ولا رفع. عربي RTL أولاً ثم إنجليزي.

## التقنية
Flutter (iOS + Android)، Riverpod، go_router، drift (SQLite)، google_maps_flutter (خريطة جوجل في الشاشة وداخل الفيديو عبر takeSnapshot، قرار المالك D9)، geolocator، gal، share_plus. إضافة أصلية محلية في packages/rihla_recorder (Kotlin/Swift) للكاميرا والدمج والترميز. بلا Firebase. التفاصيل: ARCHITECTURE.md، القرارات: DECISIONS.md، المتطلبات: SPEC.md.

## الأوامر
```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift
flutter gen-l10n
flutter analyze
flutter test
flutter test integration_test -d <device>                  # جهاز حقيقي
bash tool/gen_secrets.sh                                   # يولّد ملفات المفتاح غير المتتبَّعة من .env
flutter run --dart-define-from-file=.env                   # .env بيد المالك
bash tool/check_no_secrets.sh                              # قبل أي commit
```

## القواعد
- لا مفاتيح في الكود ولا في ملفات المنصات المتتبَّعة. GOOGLE_MAPS_API_KEY في .env (مستثنى من git) ويُحقن وقت البناء؛ المرجع .env.example (قيم فارغة). لا تطلب من المالك لصق المفتاح في المحادثة. التطبيق يجب أن يعمل ويُختبر بلا مفتاح.
- كل ما يخص الخريطة والكاميرا خلف واجهة (MapFrameSource، RecordingMap) ولها نسخة مزيّفة للاختبار.
- شعار جوجل والإسناد يبقيان ظاهرين دائماً (شاشة وفيديو): لا قص ولا تغطية.
- البناء ميزة بميزة حسب ARCHITECTURE القسم 12، وF0 أولاً.
- كل نص واجهة في ARB (ar أولاً ثم en)؛ لا نصوص ثابتة. استخدم EdgeInsetsDirectional وAlignmentDirectional لدعم RTL.
- أقل بيانات ممكنة: لا تحليلات ولا Crashlytics ولا شبكة غير SDK الخريطة.
- الأفقي فقط (يمين/يسار). الشاشة مضاءة أثناء التسجيل.
- خوارزميات الجغرافيا (تبسيط، GPX، رابط، مسافة) دوال نقية في core/geo مع اختبارات وحدة.
- features لا تستدعي القنوات الأصلية مباشرة؛ فقط عبر data/platform.
- بوابة قبول: لا يُبنى ما بعد نموذج الدمج قبل نجاحه على آيفون وأندرويد حقيقيين (ARCHITECTURE 4.3).
- القرارات المهمة تُسجَّل في DECISIONS.md؛ الحالة في STATUS.md.
- لا commit/push/دمج إلا وفق قواعد المالك العامة.
