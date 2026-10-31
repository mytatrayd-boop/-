# ARCHITECTURE — عدسة البن

مسار مجاني بلا بطاقة (قرار المالك): لا Blaze، لا Cloud Functions، لا Vertex، لا Places، لا Firebase Storage.

## 1. القرارات الأساسية
| الموضوع | القرار | السبب |
|---|---|---|
| التقنية | Flutter + Firebase **Spark** + Cloudflare Worker (مجاني) | كود واحد؛ بلا بطاقة |
| تحليل الصورة | Gemini API المجاني (AI Studio) يُستدعى **من Worker فقط** | المفتاح سر في Worker، لا في التطبيق |
| الوسيط | Cloudflare Worker (TypeScript، `wrangler`) في `worker/` | يخفي المفتاح، يتحقق، يفرض الحصة والمعدل |
| المصادقة | Firebase Auth: مجهول (ضيف) ثم Google/Apple (+ جوال إن سمحت Spark) بـ `linkWithCredential` | uid حقيقي للضيف فتُفرض الحصة عليه؛ يبقى uid بعد الدخول |
| التحقق في Worker | التحقق من Firebase ID token (JWT RS256) و App Check token بمفاتيح JWKS العامة عبر WebCrypto، بلا Admin SDK | يعمل في Worker مجاناً بلا حساب خدمة |
| الحصة والمعدل | **Durable Objects (SQLite)** في الخطة المجانية: كائن لكل uid + كائن عام للحد اليومي | ذرّية (بلا سباق) وبلا حساب خدمة؛ انظر §3 |
| تخزين محلي | drift (SQLite) + ملفات الصور | السجل والمفضلة والمقاهي على الجوال فقط |
| المقهى | `geolocator` (موقع الجهاز مرة بضغط الزر) + اسم يدوي؛ رابط خرائط بإحداثيات | بلا مفتاح ولا SDK خرائط |
| المشاركة | ودجت مخفية ← `RepaintBoundary.toImage` ← PNG ← `share_plus` | عربية سليمة بمحرك Flutter |
| الحالة / التنقل | Riverpod / go_router | |
| صور المساهمة | Cloudflare **KV** عبر Worker (بلا بطاقة) | R2 وFirebase Storage يتطلبان بطاقة؛ انظر §6 |
| الاتجاه | RTL أولاً، ARB (ar ثم en) | متطلب عام |

الصورة تُرسل مضغوطة (≤1024px، JPEG ≤ ~400KB) وتُعالج في الذاكرة في Worker ولا تُخزن، إلا صور المساهمة (§6) وبموافقة صريحة منفصلة.

## 2. تدفق الفحص
1. اختيار النوع، تصوير أو معرض، ضغط الصورة.
2. التطبيق يرسل `POST /analyze?type=bean|coffee` بجسم ثنائي (JPEG) وترويسات: `Authorization: Bearer <Firebase ID token>` و`X-Firebase-AppCheck: <token>`.
3. Worker: فحص الحجم (≤1.5MB) ← التحقق من التوكنين ← حد المعدل ← قراءة الحصة (بلا خصم) ← استدعاء Gemini بمخرجات JSON مفروضة (`responseSchema`) و temperature=0 ← تحقق من الصيغة (درجة 0–100، ملاحظات = 3، حالة `ok|unclear|not_coffee`).
4. الخصم فقط عند `ok` (استدعاء ذرّي في الـDO). `unclear/not_coffee` وأخطاء Gemini/429/الشبكة لا تُخصم.
5. الرد: `{status, score, notes[3], promptVersion, quota:{remaining}}`. التطبيق يحفظ محلياً.
- أخطاء موحدة للتطبيق: `unclear`, `busy` (429 من Gemini أو الحد اليومي الكلي، رسالة «الخدمة مشغولة»), `quota_exhausted`, `unauthorized`, `offline`.
- الطلب (prompt) في `worker/src/prompts/` بإصدار؛ يُشارك مع أداة الجدوى. التنبيه الإلزامي ثابت في الواجهة لا من النموذج.
- ثبات: temperature=0 + rubric مقنّن + تقريب الدرجة + `promptVersion`. اسم النموذج متغير إعداد (`GEMINI_MODEL`) يُحسم بنتيجة الجدوى.
- المهلة: هدف 10ث؛ Worker يقطع Gemini عند 20ث.

## 3. الحصة والمعدل والحدود (الجهة الموثوقة)
- **DO لكل uid** (`UserQuota`): `{isGuest, period "YYYY-MM" (UTC+3), used, guestUsed}`. ضيف: 2 إجمالاً بلا تجديد. مسجل: 5 شهرياً، تتجدد بمقارنة `period` داخل الـDO. `isGuest` يُستنتج من claim الموفّر في التوكن (`firebase.sign_in_provider == anonymous`) لا من العميل. عند الربط يبقى uid فلا نقل.
- **حد المعدل:** في نفس الـDO (نافذة منزلقة: ≤ 3 طلبات/دقيقة/uid) + حد لكل IP (كائن بمفتاح hash للـIP، ≤ 20/ساعة).
- **حد يومي كلي** (كائن `Global`): سقف فحوصات/يوم أقل من حد Gemini المجاني (قابل للضبط `DAILY_CAP`) يوقف الخدمة برسالة `busy`. يُقاس الاستهلاك ويُسجَّل (عدادات فقط).
- **لماذا ليس Firestore:** كتابة Firestore من Worker تتطلب حساب خدمة وتوقيع JWT وسراً إضافياً، وتتحمل قراءة/كتابة Spark (50k قراءة/20k كتابة يومياً) دون ذرّية بسيطة. **بديل إن تعذر DO:** Firestore REST بحساب خدمة مقيّد كسر Worker + معاملة. لا نحتاجه الآن.
- ثغرة معروفة: حذف التطبيق وإعادة تثبيته يعطي ضيفاً جديداً. التخفيف: App Check (Play Integrity / App Attest) + حد IP + السقف اليومي. مقبولة في التجربة.
- حدود الطبقات (تتغير، تُتحقق وقت البناء): Workers مجاني ~100k طلب/يوم؛ Gemini المجاني حد طلبات/دقيقة/يوم لكل مشروع (مئات/يوم أو أقل)؛ DO مجاني بسقف طلبات/تخزين. السقف اليومي هو الحارس الفعلي.

## 4. نموذج البيانات
**محلي (drift)** جدول `scans`: `id, type, score, notes(json 3), imagePath (اسم الملف), roasterName?, price?, createdAt, isFavorite, cafeId?, promptVersion`.
جدول `cafes`: `id, name (إلزامي), lat?, lng?, savedAt` (إحداثيات اختيارية؛ الاسم وحده مسموح). العلاقة: فحص ← مقهى واحد اختياري؛ شاشة «مقاهيّ المحفوظة» من الجدول. رابط الخرائط يُبنى وقت الحاجة من الإحداثيات: `https://www.google.com/maps/search/?api=1&query=lat,lng` (`url_launcher`)، لا يُخزن. حذف المقهى يفك ارتباط الفحوص (`cafeId=null`). هجرة drift من الإصدار الحالي (الأعمدة `placeId/placeUrl` القديمة إن وُجدت تُستبدل بـ`cafeId`).
`shared_preferences`: `signatureName`, `contributeEnabled` (افتراضه false), `disclosureAccepted`, `contributionIds` (للسحب).

**سحابي:** Firestore (Spark) فقط لـ`feedback/{id}`: `{uid, text≤2000, appVersion, createdAt}`، إنشاء فقط. لا صور ولا مواقع ولا سجل. الحصة في DO لا Firestore. صور المساهمة في KV (§6).

## 5. الأمان والخصوصية
قواعد Firestore:
```
feedback/{id}: create: request.auth != null && request.resource.data.uid == request.auth.uid
               && text is string && text.size() <= 2000 && keys().hasOnly(['uid','text','appVersion','createdAt'])
               قراءة/تعديل/حذف: ممنوع
غير ذلك: ممنوع
```
- Worker: أسرار (`GEMINI_API_KEY`) عبر `wrangler secret put` فقط. المتغيرات غير السرية (`FIREBASE_PROJECT_ID`, `DAILY_CAP`, `GEMINI_MODEL`) في `wrangler.toml`. CORS غير لازم (تطبيق أصلي). رفض أي طلب بلا توكن صالح، بلا تسجيل صور أو توكنات في السجلات.
- التطبيق: عنوان Worker وإعدادات Firebase العامة عبر `--dart-define-from-file=.env`؛ `google-services.json` و`GoogleService-Info.plist` و`.dev.vars` مستثناة من git. تفتيش الحزمة للتأكد من خلوها من مفتاح Gemini (اختبار قبول).
- الموقع: يُطلب «عند الاستخدام» بضغط الزر فقط، مرة واحدة، يبقى محلياً، ويُشارك فقط بضغط المشاركة. لا تتبع.
- إفصاح قبل أول فحص: الصورة تُرسل لـGemini، وفي الطبقة المجانية قد تستخدمها قوقل لتحسين منتجاتها؛ لا تُرسل وجوه ولا موقع. شروط Gemini المجانية قد تمنع استخدامها لمستخدمين في الاتحاد الأوروبي/بريطانيا/سويسرا، فالإطلاق التجريبي للسعودية/الخليج فقط.
- سياسة الخصوصية للمتاجر، وحذف الحساب من التطبيق (Apple): يحذف مستخدم Firebase ومسار حذف DO عبر `DELETE /account`.

## 6. المساهمة بالبيانات
- مفتاح «ساهم بصوري» مغلق افتراضياً + شاشة شرح (ماذا/لماذا/كيف أسحب). لا رفع قبل التفعيل.
- الرفع: `POST /contribute` (نفس التحقق والمعدل) بالصورة المضغوطة + `{type, score, promptVersion, appVersion}`؛ لا uid ولا موقع ولا اسم في المحتوى المخزن. Worker يولد `contributionId` عشوائياً (UUID) ويعيده للتطبيق ليحتفظ به محلياً.
- التخزين: **Workers KV** (مجاني بلا بطاقة، 1GB، ~1000 كتابة/يوم): المفتاح `c:{id}`، القيمة الصورة، والبيانات الوصفية في metadata. يكفي ~2000–3000 صورة (400KB) وهو كافٍ لـ20–30 مختبراً. بديل إن امتلأ: D1 (5GB مجاني) أو تفريغ دوري إلى جهاز المالك. R2 مرفوض (يتطلب بطاقة). الجمع اليدوي من جوالات المختبرين احتياطي.
- السحب: إيقاف المفتاح يوقف الجمع مستقبلاً؛ حذف ما أُرسل: `DELETE /contribute/{id}` بالـid المحفوظ محلياً (دون ربط بالحساب).
- التصدير: سكربت للمالك (`tools/export-contrib/`) عبر `wrangler kv` إلى مجلد محلي + CSV تقييم الخبير. التقييم والتدريب خارج التطبيق.

## 7. المكتبات (مستقرة ومشهورة)
`firebase_core, firebase_auth, firebase_app_check, cloud_firestore (feedback فقط), firebase_crashlytics, google_sign_in, sign_in_with_apple, flutter_riverpod, go_router, drift + sqlite3 + path_provider + path, image_picker, flutter_image_compress, share_plus, url_launcher, geolocator, http, shared_preferences, intl + flutter_localizations`. محذوف: `cloud_functions`. اختبار: `flutter_test, mocktail`؛ Worker: `vitest` + `@cloudflare/vitest-pool-workers`، و`wrangler`.
- الخطوط العربية مضمّنة في assets. لا خرائط SDK.
- لاحقاً للنموذج الخاص: `tflite_flutter` (قرار عند البدء).

## 8. صورة المشاركة
1080×1350: صورة الفحص، الدرجة، اسم المقهى، التوقيع بخط يدوي، اللوقو، تنبيه «تقدير بصري تقريبي». النص المرافق فيه اسم المقهى ورابط الخرائط إن وُجد. تُولَّد عند الضغط وتُحذف مؤقتاتها بعد المشاركة. اللوقو: `assets/logo.png` شفاف (+ نسخة بيضاء) واختبار بصري على الخلفيتين.

## 9. هيكل المجلدات
```
lib/  main.dart, app.dart
  core/ (theme, l10n, router, config, errors)
  data/ (db/drift, repositories, services/{analysis,auth,location,share,contribution})
  domain/ (Scan, Cafe, AnalysisResult, Quota)
  features/ scan result history favorites cafes share auth settings feedback contribute
  l10n/ app_ar.arb, app_en.arb
worker/  src/{index,auth,quota(DO),gemini,contribute}.ts, src/prompts/, test/, wrangler.toml
tools/feasibility/   اختبار الجدوى (Gemini API بمفتاح AI Studio من البيئة)
tools/export-contrib/ تصدير صور المساهمة (للمالك)
test/ , firestore.rules, firebase.json, .env.example
```
الاعتماد باتجاه واحد: features ← domain/data ← core. الواجهة لا تستدعي Firebase/الشبكة مباشرة بل عبر repository/service.

## 10. اختبار الجدوى (بوابة)
أداة `tools/feasibility/` تستدعي **Gemini API المجاني** بمفتاح `GEMINI_API_KEY` من البيئة (ليس Vertex) وبنفس الطلب من `prompts/`. 40 بن + 40 قهوة، خبير بمقياس 100 قبل رؤية النتائج، كل صورة مرتين، والمعايير في SPEC وتفسيرها في DECISIONS. نجاح ← نكمل. فشل لنوع ← «مؤشرات بصرية» أو إيقاف النوع. تُسجَّل النتيجة في DECISIONS.md. تُقاس أيضاً حدود المعدل الفعلية للطبقة المجانية.

## 11. ترتيب البناء
مستقل عن الوسيط أولاً:
1. (منجز) هيكل المشروع، الثيم، RTL/l10n، الاختبارات، CI.
2. (منجز) السجل المحلي drift + الحذف بتأكيد.
3. المفضلة.
4. المقهى: geolocator + جدول `cafes` + «مقاهيّ المحفوظة» + رابط الخرائط + حالة رفض الإذن.
5. المشاركة: صورة المشاركة + اللوقو الشفاف + `share_plus`.
ثم الوسيط:
6. بوابة الجدوى (تعمل بالتوازي من البداية لأنها لا تحتاج التطبيق).
7. Worker: التحقق (ID token + App Check) + DO للحصة/المعدل/السقف + Gemini + اختبارات.
8. شاشة التصوير والنتيجة مع الحالات (غير واضح، مشغول، بلا إنترنت) + إفصاح ما قبل أول فحص ← أول مسار كامل للضيف.
9. تسجيل الدخول وربط الضيف + اسم التوقيع + حذف الحساب + الحصة الشهرية.
10. المساهمة بالبيانات (`/contribute`).
11. الملاحظات، Crashlytics، سياسة الخصوصية، التوزيع التجريبي.
البنود 8–11 لا تبدأ قبل نجاح البند 6.

## 12. المسار اللاحق: نموذج خاص على الجوال (TFLite)
- **البيانات:** صور المساهمة (KV) + تقييم خبير موحد (CSV: contributionId، نوع، درجة، صحة الملاحظات). أهداف أولية: ≥500 صورة لكل نوع، وتوزيع متوازن عبر الدرجات. درجات Gemini تُحفظ كتسمية ضعيفة مساعدة لا بديلة عن الخبير.
- **التدريب:** خارج التطبيق (Colab المجاني): نقل التعلم من MobileNetV3/EfficientNet-Lite، انحدار للدرجة (أو تصنيف فئات) ثم تحويل إلى TFLite وتكميم.
- **الدمج:** `tflite_flutter` خلف واجهة `AnalysisService` نفسها (تبديل التنفيذ بإعداد)، فلا تتغير الشاشات. الملاحظات الثلاث من قوالب مبنية على مؤشرات النموذج. يُقاس مقابل الخبير بنفس معايير الجدوى قبل اعتماده.
- **ثمرته:** يلغي حدود Gemini ومخاطر خصوصية الطبقة المجانية ويعمل بلا إنترنت. لا يبدأ قبل توفر البيانات.

## 13. ما يحتاج المالك
1. مفتاح Gemini من aistudio.google.com (يوضع كسر في Worker وفي بيئتك لأداة الجدوى؛ لا يُلصق في أي ملف أو محادثة).
2. حساب Cloudflare مجاني (بلا بطاقة) للـWorker وDO وKV. (يُتحقق أن إنشاء DO/KV لا يطلب بطاقة.)
3. مشروع Firebase Spark وإعدادات الدخول (Google؛ الجوال إن سمحت Spark بلا Blaze؛ Apple يتطلب حساب مطوّر).
4. الموافقة على نص إفصاح الخصوصية (الصورة قد تُستخدم من قوقل في الطبقة المجانية) وسياسة الخصوصية.
5. صور الاختبار (80) وخبير التقييم، وملف اللوقو الأصلي إن وُجد.
6. قرار التوزيع التجريبي: أندرويد APK مباشر/Firebase App Distribution مجاناً؛ آيفون يتطلب حساب Apple Developer (مدفوع)؛ Google Play يتطلب رسماً لمرة واحدة.
