# عدسة البن (Bunn Lens)

تطبيق يفحص البن والقهوة بصورة واحدة ويعطي درجة من 100 و3 ملاحظات عربية (تقدير بصري فقط). عربي RTL أولاً ثم الإنجليزية. التفاصيل: IDEA.md، SPEC.md، ARCHITECTURE.md، DECISIONS.md.

## التقنية (مسار مجاني بلا بطاقة)
Flutter + Riverpod + go_router + drift (محلي) • Firebase **Spark** فقط (Auth، Firestore للملاحظات، App Check، Crashlytics) • تحليل الصورة: Gemini API المجاني عبر **Cloudflare Worker** (`worker/`) يخفي المفتاح ويفرض الحصة (Durable Objects) والمعدل والتحقق • المقهى: `geolocator` + رابط خرائط بإحداثيات • لا Blaze/Cloud Functions/Vertex/Places/Storage/R2.

## الأوامر
```
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=.env
dart run build_runner build --delete-conflicting-outputs   # drift
flutter gen-l10n
cd worker && npm ci && npm test && npx wrangler dev        # الوسيط محلياً (.dev.vars)
cd worker && npx wrangler secret put GEMINI_API_KEY        # بإدخال المالك فقط
node tools/feasibility/run.mjs ...                         # يقرأ GEMINI_API_KEY من البيئة
```
(الأوامر تعمل بعد إنشاء الهيكل؛ لا تدّعِ نجاحها قبل تشغيلها فعلاً.)

## القواعد
- العربية RTL أولاً: `EdgeInsetsDirectional` و`AlignmentDirectional`، وكل نص من ARB.
- لا مفاتيح ولا كلمات مرور ولا أسرار في أي ملف أو محادثة. `.env` و`.dev.vars` مستثناة من git (`.env.example` فارغ القيم). مفتاح Gemini سر في Worker فقط ولا يدخل التطبيق أبداً. `google-services.json` و`GoogleService-Info.plist` مستثناة.
- الحصة والمعدل والتحقق في Worker فقط، لا في العميل. كل طلب يحمل Firebase ID token وApp Check token.
- الصور تُعالج ولا تُخزن، إلا صور المساهمة بعد تفعيل المفتاح الصريح (افتراضه مغلق؛ بلا موقع ولا اسم ولا حساب).
- الموقع يُؤخذ بضغط زر «احفظ مكان المقهى» فقط، يبقى محلياً، بلا تتبع. التطبيق يعمل كاملاً بدونه.
- التنبيه «التقدير بصري تقريبي وليس حكماً نهائياً» دائماً في النتيجة وصورة المشاركة.
- 3 ملاحظات بالضبط؛ الفحص غير الواضح أو 429 أو بلا إنترنت أو تعطل الوسيط لا يُحتسب.
- المشاركة والنشر والدفع وحذف البيانات: فقط بضغط المستخدم أو بموافقة المالك الصريحة.
- الواجهة لا تستدعي Firebase أو الشبكة مباشرة، بل عبر repository/service. ملفات صغيرة، أسماء واضحة، لا مكتبات غير مشهورة بلا قرار في DECISIONS.md.
- كل ميزة بها اختبار؛ الوسيط باختبارات vitest. شغّل `flutter analyze` و`flutter test` قبل أي تسليم.
- بوابة الجدوى (ARCHITECTURE §10) تمنع بناء الميزات المعتمدة على الوسيط (ترتيب §11 البنود 8–11). الميزات المستقلة (السجل، المفضلة، المقهى، المشاركة) تُبنى قبلها.
- لا تفعل شيئاً يتطلب بطاقة أو ترقية خطة. إن لزم، توقف واسأل المالك.
- سجّل كل قرار مهم وسببه في DECISIONS.md، وحدّث STATUS.md عند كل مرحلة.
