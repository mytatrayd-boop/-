# عدسة البن (Bunn Lens)

تطبيق يفحص البن والقهوة بصورة واحدة ويعطي درجة من 100 و3 ملاحظات عربية (تقدير بصري فقط). عربي RTL أولاً ثم الإنجليزية. التفاصيل: IDEA.md، SPEC.md، ARCHITECTURE.md، DECISIONS.md.

## التقنية
Flutter + Riverpod + go_router + drift (محلي) • Firebase (Auth, Firestore, Cloud Functions Gen2 بـ TypeScript, App Check, Crashlytics) • تحليل الصورة عبر دالة سحابية تستدعي نموذج رؤية (Vertex AI).

## الأوامر
```
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=.env
dart run build_runner build --delete-conflicting-outputs   # drift
flutter gen-l10n
cd functions && npm ci && npm test && npm run build
firebase emulators:start --only auth,firestore,functions
```
(الأوامر تعمل بعد إنشاء الهيكل؛ لا تدّعِ نجاحها قبل تشغيلها فعلاً.)

## القواعد
- العربية RTL أولاً: استخدم `EdgeInsetsDirectional` و`AlignmentDirectional`، وكل نص من ARB لا نصوص ثابتة في الكود.
- لا مفاتيح ولا كلمات مرور ولا أسرار في أي ملف. استخدم `.env` (مستثنى من git؛ المثال `.env.example` فارغ القيم) أو Secret Manager. `google-services.json` و`GoogleService-Info.plist` مستثناة.
- الحصة والتحقق دائماً في الخادم، لا في العميل. الدوال تتطلب App Check والمصادقة.
- الصور تُعالج ولا تُخزن في السحابة. الموقع يُختار يدوياً فقط، بلا تتبع. أقل بيانات ممكنة.
- التنبيه «التقدير بصري تقريبي وليس حكماً نهائياً» يظهر دائماً في النتيجة وصورة المشاركة.
- 3 ملاحظات بالضبط؛ فحص غير واضح أو بلا إنترنت لا يُحتسب.
- المشاركة والنشر والدفع وحذف البيانات: فقط بضغط المستخدم أو بموافقة المالك الصريحة.
- الواجهة لا تستدعي Firebase مباشرة، بل عبر repository. ملفات صغيرة، أسماء واضحة، بلا مكتبات غير مشهورة بلا قرار في DECISIONS.md.
- كل ميزة بها اختبار (وحدة/ودجت)؛ الدوال باختبارات مع emulator. شغّل `flutter analyze` و`flutter test` قبل أي تسليم.
- لا تبنِ بقية التطبيق قبل اجتياز بوابة اختبار الجدوى (ARCHITECTURE §9).
- سجّل كل قرار مهم وسببه في DECISIONS.md، وحدّث STATUS.md عند كل مرحلة.
