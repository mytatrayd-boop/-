# ARCHITECTURE — عدسة البن

## 1. القرارات الأساسية (مختصرة)
| الموضوع | القرار | السبب |
|---|---|---|
| التقنية | Flutter + Firebase | الافتراضي؛ كود واحد للآيفون والأندرويد |
| تحليل الصورة | Cloud Function (Gen2) تستدعي نموذج رؤية عبر **Vertex AI (Gemini)** | الدخول بحساب خدمة (IAM) فلا مفتاح API أصلاً؛ بدائل (OpenAI/Anthropic) تحتاج سراً في Secret Manager فقط. اسم النموذج إعداد في الدالة ويُحسم بنتيجة اختبار الجدوى |
| المصادقة | Firebase Auth: **مجهول (ضيف)** ثم جوال/Apple/Google بربط الحساب (`linkWithCredential`) | الضيف يحصل uid حقيقي فتُفرض الحصة من الخادم، وبعد الدخول يبقى نفس uid فلا نقل بيانات |
| الحصة | تُفرض في الدالة داخل معاملة Firestore | العميل لا يُوثق به |
| تخزين الضيف/السجل | محلي: **drift (SQLite)** + ملفات الصور في مجلد التطبيق | بلا حساب، خصوصية، أبسط. المصدر الوحيد للسجل والمفضلة في MVP |
| الخرائط | Places API (New) **عبر الدالة** للبحث؛ حفظ placeId+الاسم+الإحداثيات+الرابط | المفتاح يبقى في الخادم؛ لا تتبع للموقع |
| صورة المشاركة | ودجت Flutter مخفية → `RepaintBoundary.toImage` → PNG → `share_plus` | يضمن تشكيل العربية الصحيح بمحرك Flutter نفسه |
| الاتجاه | RTL أولاً، `flutter_localizations` + ARB (ar أولاً، en) | متطلب عام |
| الحالة | Riverpod | مستقر ومشهور وقابل للاختبار |
| التنقل | go_router | |

التحليل لا يُحفظ على الخادم: الصورة تُرسل مضغوطة (≤1024px، JPEG) وتُعالج في الذاكرة ولا تُخزن. لا Firebase Storage في MVP.

## 2. تدفق الفحص
1. المستخدم يختار (بن/قهوة) ثم يصور أو يختار من المعرض.
2. التطبيق يصغّر الصورة ويستدعي `analyzeImage({type, imageBase64})` (Callable، App Check مفعّل، المستخدم مسجل ولو مجهولاً).
3. الدالة: تتحقق من الحصة (قراءة فقط) ← تستدعي النموذج بمخرجات JSON مفروضة (schema) و temperature=0 ← تتحقق من الصيغة (درجة 0–100، ملاحظات = 3 بالضبط، حالة `ok | unclear | not_coffee`).
4. فقط عند `ok` تُخصم الحصة (معاملة) وتُعاد النتيجة. `unclear/not_coffee` وأخطاء الشبكة/النموذج لا تُخصم.
5. التطبيق يحفظ النتيجة محلياً فوراً.
- المهلة: 10 ثوانٍ هدف؛ مهلة الدالة 30 ثانية؛ يقاس زمن كل مرحلة في السجلات.
- ثبات الدرجة: temperature=0 + طلب بمعايير مقنّنة (rubric) + تقريب الدرجة لأقرب 1 + نسخة الطلب `promptVersion` تُحفظ مع النتيجة.
- الصياغة: تقدير بصري، والتنبيه الإلزامي ثابت في الواجهة (لا من النموذج).
- الطلب (prompt) في `functions/src/prompts/` بإصدار؛ نص مستقل لكل نوع.

## 3. الحصة
- مستند `users/{uid}`: `{displayName?, isGuest, quota:{period:"YYYY-MM", used:n}, createdAt}`.
- الضيف: 2 إجمالاً (لا تتجدد). مسجل: 5 شهرياً، تتجدد بمقارنة `period` بالشهر الحالي (UTC+3) داخل المعاملة، فلا حاجة لمهمة مجدولة.
- عند ربط الحساب: الدالة `onLinked` (أو أول استدعاء) تحول `isGuest=false` وتضبط حصة الشهر.
- ثغرة معروفة: حذف التطبيق وإعادة تثبيته يعطي ضيفاً جديداً. التخفيف: App Check (App Attest/Play Integrity) + حد معدل للمعدل لكل IP/جهاز. نقبل الباقي في التجربة.
- الاشتراك لاحقاً: حقل `plan` موجود ويُقرأ في نفس المعاملة.

## 4. نموذج البيانات
**محلي (drift)** جدول `scans`: `id, type(bean|coffee), score, notes(json 3), imagePath, roasterName?, price?, createdAt, isFavorite, placeId?, placeName?, placeLat?, placeLng?, placeUrl?, promptVersion`. المفضلة = `isFavorite` (لا جدول مستقل). اسم التوقيع في `shared_preferences` (`signatureName`).

**سحابي (Firestore)**:
- `users/{uid}` كما أعلاه.
- `feedback/{id}`: `{uid, text, appVersion, createdAt}` (إنشاء فقط).
- لا صور ولا مواقع ولا سجل فحوصات في السحابة.

## 5. قواعد الأمان (Firestore)
```
users/{uid}: read: auth.uid == uid ؛ write: ممنوع (الدوال فقط عبر Admin SDK)
             ما عدا تحديث displayName فقط (affectedKeys().hasOnly(['displayName']))
feedback/{id}: create: مسجل (حتى المجهول) وطول النص ≤ 2000 وuid == auth.uid ؛ لا قراءة/تعديل/حذف
غير ذلك: ممنوع
```
- كل الدوال: `enforceAppCheck: true`، تحقق من `request.auth`، حد حجم الصورة (≤1.5MB)، حد معدل.
- الأسرار (إن لزمت): Secret Manager فقط. المفاتيح العامة للعميل (إعدادات Firebase، مفتاح خرائط مقيّد بالحزمة/SHA) عبر `--dart-define-from-file=.env` لا تُرفع إلى git. ملفات `google-services.json` و`GoogleService-Info.plist` مستثناة.
- سياسة الخصوصية مطلوبة للمتاجر: الصورة تُرسل للتحليل ولا تُخزن، الموقع يدوي فقط، حذف الحساب من داخل التطبيق (متطلب Apple).

## 6. المكتبات (مستقرة ومشهورة فقط)
`firebase_core, firebase_auth, cloud_firestore, cloud_functions, firebase_app_check, firebase_crashlytics, google_sign_in, sign_in_with_apple, flutter_riverpod, go_router, drift + sqlite3_flutter_libs + path_provider, image_picker, flutter_image_compress, share_plus, url_launcher, shared_preferences, intl + flutter_localizations`. اختبار: `flutter_test, mocktail`، ودوال: `jest` أو `vitest` مع Firebase Emulator.
- لا خرائط SDK في MVP (البحث نصي عبر Places + فتح الرابط في تطبيق الخرائط). نضيف `google_maps_flutter` فقط إن طلبت معاينة خريطة.
- الخطوط (عربي) تُضمَّن في assets (مثل IBM Plex Sans Arabic/Noto Kufi + خط يدوي للتوقيع) لا تحميل وقت التشغيل، ليعمل توليد الصورة دائماً.

## 7. صورة المشاركة
ودجت ثابتة 1080×1350: صورة الفحص، الدرجة، اسم المقهى، التوقيع (اسم المستخدم بخط يدوي)، اللوقو، وتنبيه «تقدير بصري تقريبي». النص المرافق يحوي رابط الخرائط إن وُجد. تُولَّد عند الضغط فقط وتُحذف من الملفات المؤقتة بعد المشاركة.
**اللوقو:** `assets/logo-source.jpg` مصدر فقط. ننتج `assets/logo.png` شفافاً حقيقياً (تفريغ الخلفية؛ الأفضل أصل SVG/PNG من المالك) ونسخة معكوسة فاتحة للخلفيات الداكنة `logo-light.png`. اللوقو حبر أسود، لذا يوضع على لوح فاتح أو بنسخة بيضاء حسب الخلفية. اختبار بصري على الخلفيتين إلزامي.

## 8. هيكل المجلدات
```
lib/
  main.dart, app.dart
  core/        (theme, l10n, router, config, errors, utils)
  data/        (db/drift, repositories, services/{analysis,places,auth,share})
  domain/      (models: Scan, Place, AnalysisResult, Quota)
  features/    scan/ result/ history/ favorites/ place_picker/ share/ auth/ settings/ feedback/
  l10n/        app_ar.arb, app_en.arb
assets/        logo*.png, fonts/
functions/     src/{analyzeImage,searchPlaces,deleteAccount}.ts, src/prompts/, test/
tools/feasibility/   سكربت اختبار الجدوى + بيانات التقييم (الصور خارج git)
test/          unit + widget ؛ integration_test/
firestore.rules, firebase.json, .env.example
```
الاعتماد باتجاه واحد: features → domain/data → core. لا تستدعي الواجهة خدمة Firebase مباشرة بل عبر repository.

## 9. خطة اختبار الجدوى المبكر (قبل بناء التطبيق)
1. نبني `tools/feasibility/` (Node) يستخدم **نفس** الطلب ونفس الاستدعاء الذي ستستخدمه الدالة (يُشارك كود `prompts/`).
2. 40 صورة بن + 40 قهوة (من المالك/المختبرين)، يقيّمها خبير أو اثنان بمقياس 100 قبل رؤية النتائج، في ملف CSV.
3. كل صورة تُفحص مرتين؛ السكربت يحسب: نسبة فرق ≤10 عن الخبير (هدف 70%)، ثبات ≤5 (هدف 90%)، فصل «ضعيفة» عن «ممتازة»، وتقييم الخبير للملاحظات (هدف 70%)، مع الزمن والتكلفة لكل فحص.
4. القرار (بوابة): نجاح ← نكمل. فشل لنوع ← تحويل إلى «مؤشرات بصرية» أو إيقاف النوع (غالباً القهوة المشروبة). تُسجَّل النتيجة في DECISIONS.md. مقارنة نموذجين أو أكثر ممكنة في نفس السكربت لاختيار الأفضل سرعةً ودقةً وتكلفة.
5. مؤقتاً قبل وصول الصور: نختبر بصور عامة للتحقق من الصيغة والزمن فقط، لا الدقة.

## 10. ترتيب بناء الميزات
0. **بوابة الجدوى** (§9) + تفريغ اللوقو (بالتوازي).
1. هيكل المشروع، الثيم، RTL/l10n، Firebase (مع emulator)، CI (`analyze` + `test`).
2. دالة `analyzeImage` + الحصة + App Check، واختبارات الدالة.
3. شاشة البداية والتصوير وشاشة النتيجة (مع حالات: غير واضح، بلا إنترنت) — أول مسار كامل عند الضيف.
4. السجل المحلي (drift) + الحذف بتأكيد.
5. المفضلة.
6. تسجيل الدخول وربط الضيف + اسم التوقيع + حذف الحساب.
7. اختيار المقهى (Places عبر الدالة).
8. صورة المشاركة.
9. إرسال الملاحظات، Crashlytics، سياسة الخصوصية، توزيع تجريبي (TestFlight + Firebase App Distribution) لـ20–30 مختبراً.

## 11. افتراضات الأسئلة المفتوحة
1. الضيف: محلي فقط حتى الدخول ← نعم. 2. الصور والخبير ← مطلوبة من المالك (تعطل البوابة). 3. اللوقو ← نفرّغ من الحالي مؤقتاً. 4. التوقيع ← يكتبه المستخدم ويعدله، مع اقتراح من الحساب. 5. المشاركة ← صورة + نص برابط الموقع.

## 12. نقاط تحتاج المالك لاحقاً (لا يُنفذ بدونه)
مشروع Firebase بخطة Blaze (مطلوبة للدوال ولمصادقة الجوال)، حساب Apple Developer، تفعيل Vertex AI وPlaces API في مشروع Google Cloud، إعدادات تسجيل الدخول. تُحفظ المفاتيح في `.env` أو Secret Manager فقط.
