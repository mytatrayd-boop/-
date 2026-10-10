# دليل النشر التجريبي — Google Play و App Store (TestFlight)

هذا الدليل يوصلك من الكود إلى نسخة تجريبية على جوالات أسرتك. **لا تحتاج جهاز Mac**: البناء يتم على GitHub Actions (خوادم Linux و macOS مجانية للمستودعات العامة، ومحدودة الدقائق للخاصة).

> يمكنك رفع نسخة Android تجريبية **قبل** إعداد الخادم: التطبيق يعمل حينها بـ«التجربة السريعة» فقط (بيانات على الجهاز). لتسجيل الدخول الحقيقي بالبريد أكمل الخطوات 1–3.

## ما ستحتاجه

| الحساب | التكلفة | لماذا |
|---|---|---|
| Google Firebase (الخطة المجانية Spark) | مجاني، بدون بطاقة | قاعدة البيانات وتسجيل الدخول والإشعارات |
| Netlify (الخطة المجانية) | مجاني، بدون بطاقة | الخادم وصفحة الخصوصية |
| Gmail (بريدك) | مجاني (حتى ~500 رسالة/يوم) | إرسال أكواد الدخول |
| Google Play Console | 25$ مرة واحدة | نشر Android |
| Apple Developer Program | 99$ سنوياً | نشر iPhone |

> لماذا ليس خطة Firebase المدفوعة (Blaze)؟ حساب الدفع في السعودية يمر عبر CNTXT ويطلب سجلاً تجارياً ورقماً ضريبياً. لذلك يعمل الخادم على Netlify. إن حصلت لاحقاً على سجل تجاري يمكن نقله إلى Cloud Functions بدون تغيير في الكود.

المفاتيح السرية تُحفظ في **GitHub → المستودع → Settings → Secrets and variables → Actions → New repository secret**. لا تضعها في الكود ولا ترسلها في المحادثة.

---

## 1) Firebase (مجاني)

1. [console.firebase.google.com](https://console.firebase.google.com) ← أنشئ مشروعاً (أوقف Google Analytics). **لا تحتاج الترقية إلى Blaze.**
2. **Firestore Database** ← Create database ← Standard ← الموقع `me-central2 (Dammam)` ← Production mode.
3. **Authentication** ← Get started (لا تفعّل أي مزوّد).
4. **Project settings ← General ← Your apps**: أضف تطبيق **Android** بالمعرّف `sa.asraty.app` وتطبيق **iOS** بنفس المعرّف (تجاوز تنزيل الملفات بـ Next).
5. أرسل قيم صفحة Project settings (Project ID، Project number، Web API key، App ID لكل تطبيق) — هذه ليست أسراراً، وتوضع في `app/env.prod.json`.
6. **Project settings ← Service accounts ← Generate new private key** ← ينزل ملف JSON. افتحه وانسخ محتواه كاملاً إلى سر GitHub باسم **`FIREBASE_SERVICE_ACCOUNT_JSON`**. ⚠️ هذا الملف سرّي: لا ترسله لأحد واحذفه من جهازك بعد النسخ.

## 2) البريد (Gmail)

1. في حساب Google لبريد الإرسال (مثل `asraty200@gmail.com`) فعّل **التحقق بخطوتين**: [myaccount.google.com/security](https://myaccount.google.com/security).
2. افتح [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) ← اكتب اسماً مثل `asraty` ← Create ← تظهر كلمة مرور من 16 حرفاً.
3. أسرار GitHub:
   - `GMAIL_USER` = عنوان البريد.
   - `GMAIL_APP_PASSWORD` = كلمة مرور التطبيق (16 حرفاً).

## 3) الخادم (Vercel أو Netlify)

**Vercel:** [vercel.com/signup](https://vercel.com/signup) ← Continue with GitHub ← Hobby، ثم [vercel.com/account/settings/tokens](https://vercel.com/account/settings/tokens) ← Create (No expiration) ← سر GitHub باسم `VERCEL_TOKEN`. إن طلب Vercel توثيق الجوال ولم تصل الرسالة، استخدم Netlify:

**Netlify:**

1. [app.netlify.com/signup](https://app.netlify.com/signup) ← **Sign up with GitHub**.
2. [app.netlify.com/user/applications#personal-access-tokens](https://app.netlify.com/user/applications#personal-access-tokens) ← **New access token** ← الاسم `github` ← Expiration «No expiration» ← Generate ← انسخ الرمز.
3. سر GitHub: `NETLIFY_AUTH_TOKEN`.
4. **Actions ← «Asraty — deploy backend» ← Run workflow.** ينشر قواعد الأمان إلى Firebase والخادم إلى Netlify على `https://asraty-<اسم حساب GitHub>.netlify.app`، ثم يختبر أن الخادم يرد ويقرأ قاعدة البيانات.
5. هذا الرابط هو `SERVER_URL` في `app/env.prod.json`.

صفحة سياسة الخصوصية: `https://<رابط الخادم>/privacy` — وصفحة حذف الحساب: `…/delete-account`. ستحتاجهما في المتجرين.

---

## 4) Android — Google Play (اختبار داخلي)

### أ) مفتاح الرفع (مرة واحدة)
على أي جهاز فيه Java:
```bash
keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload.jks > upload.b64      # على Mac: base64 -i upload.jks -o upload.b64
```
احتفظ بالملف وكلمة المرور في مكان آمن. أسرار GitHub:
`ANDROID_KEYSTORE_BASE64` (محتوى upload.b64) · `ANDROID_KEYSTORE_PASSWORD` · `ANDROID_KEY_ALIAS` = `upload` · `ANDROID_KEY_PASSWORD`.

### ب) البناء
**Actions ← «Asraty — Android» ← Run workflow**. عند انتهائه نزّل ملف `app-release.aab` من قسم Artifacts.

### ج) Play Console (أول مرة يدوياً)
1. [play.google.com/console](https://play.google.com/console) ← Create app ← الاسم «أسرتي»، اللغة الافتراضية العربية، App، Free.
2. **Testing ← Internal testing ← Create new release** ← ارفع ملف `.aab` ← Save ← Review ← Start rollout.
   - أول مرة سيطلب تفعيل **Play App Signing** — وافق.
3. **Testers**: أنشئ قائمة بإيميلات Gmail لأسرتك، وانسخ **رابط الانضمام** وأرسله لهم.
4. أكمل **App content** (مطلوب حتى للاختبار):
   - Privacy policy: رابط `/privacy`.
   - App access: «كل الميزات متاحة» مع ملاحظة أن «تجربة سريعة بأسرة جاهزة» تتيح التجربة بدون حساب.
   - Ads: لا.
   - Data safety: الاسم، البريد، الصور (اختيارية)، معرّفات الجهاز (رمز الإشعارات) — مشفّرة أثناء النقل، يمكن طلب حذفها، رابط الحذف `/delete-account`.
   - Target audience: إذا اخترت فئات تحت 13 سنة تنطبق [سياسة العائلات](https://support.google.com/googleplay/android-developer/answer/9893335). التطبيق متوافق معها (بلا إعلانات ولا أدوات تتبّع).

### د) الرفع التلقائي لاحقاً (اختياري)
Play Console ← Setup ← API access ← اربط مشروع Google Cloud وأنشئ Service account، وامنحه صلاحية «Release to testing tracks» للتطبيق. ضع ملف JSON في السر `PLAY_SERVICE_ACCOUNT_JSON`. بعدها كل تشغيل للـ workflow يرفع الإصدار مباشرة إلى المسار الذي تختاره (internal افتراضياً).
> إذا ظهر خطأ «Only releases with status draft may be created on draft app» شغّل الـ workflow مع `status = draft` ثم اعتمد الإصدار من Play Console.

---

## 5) iPhone — App Store Connect (TestFlight)

1. **App ID**: [developer.apple.com ← Identifiers](https://developer.apple.com/account/resources/identifiers) ← + ← App IDs ← Bundle ID `sa.asraty.app` ← فعّل **Push Notifications**.
2. **مفتاح الإشعارات (APNs)**: Keys ← + ← فعّل Apple Push Notifications service ← نزّل ملف `.p8`. ثم في Firebase ← Project settings ← Cloud Messaging ← Apple app configuration ← ارفع المفتاح مع Key ID و Team ID.
3. **App Store Connect**: [appstoreconnect.apple.com](https://appstoreconnect.apple.com) ← Apps ← + ← New App ← iOS، الاسم «أسرتي»، اللغة Arabic، Bundle ID `sa.asraty.app`، SKU مثل `asraty-001`.
4. **مفتاح API للبناء**: App Store Connect ← Users and Access ← Integrations ← App Store Connect API ← + ← الدور **Admin** (مطلوب للتوقيع التلقائي) ← نزّل `.p8`.
5. أسرار GitHub:
   - `APPSTORE_API_KEY_P8` = محتوى ملف `.p8` كاملاً (بما فيه سطري BEGIN/END).
   - `APPSTORE_API_KEY_ID` = Key ID.
   - `APPSTORE_API_ISSUER_ID` = Issuer ID (أعلى صفحة المفاتيح).
   - `APPLE_TEAM_ID` = Team ID (من developer.apple.com ← Membership).
6. **Actions ← «Asraty — iOS (TestFlight)» ← Run workflow**. بعد 10–30 دقيقة من انتهائه يظهر الإصدار في App Store Connect ← TestFlight.
7. في TestFlight: سؤال التشفير مضبوط تلقائياً (لا تشفير خاص). التطبيق لآيفون فقط فلا يحتاج لقطات آيباد، ثم **Internal Testing ← +** وأضف إيميلات Apple ID لأسرتك (حتى 100 شخص، بدون مراجعة). يثبّتون تطبيق **TestFlight** من App Store ثم يقبلون الدعوة.
   - للمختبرين الخارجيين (حتى 10,000) تحتاج مراجعة Beta سريعة: اذكر في ملاحظات المراجعة أن زر «تجربة سريعة بأسرة جاهزة» يتيح تجربة كل الميزات بدون حساب.

---

## 6) بعد التثبيت — جرّب هذا
1. «مسؤول الأسرة» ← اسم الأسرة واسمك وبريدك ← الكود من البريد ← تُنشأ أسرتك.
2. «إضافة عضو أسرة» ← يصل للطفل بريد فيه الكود ← يدخل من «أحد أفراد الأسرة».
3. أضف مهمة ← الطفل يضغط «أنجزتها» (مع صورة اختيارية) ← يصلك إشعار ← وافق ← تظهر النقاط.

## تحديث نسخة جديدة
ارفع رقم الإصدار في `asraty/app/pubspec.yaml` (مثلاً `version: 1.0.1+1`) عند تغيير الميزات. رقم البناء يُضبط تلقائياً من رقم تشغيل الـ workflow، فيكفي تشغيل الـ workflow مرة أخرى.

## مشاكل شائعة
| المشكلة | الحل |
|---|---|
| «تعذّر الاتصال» عند طلب الكود | تأكد أن الخادم منشور (الخطوة 3) وأن `SERVER_URL` صحيح في `app/env.prod.json`. |
| يصل الكود لكن التحقق يفشل بخطأ عام | تأكد أن `FIREBASE_SERVICE_ACCOUNT_JSON` من نفس مشروع Firebase، ثم أعد تشغيل «deploy backend». |
| لا يصل البريد | تحقق من كلمة مرور التطبيق في Gmail (`GMAIL_APP_PASSWORD`) وأن التحقق بخطوتين مفعّل. راجع Netlify ← الموقع ← Logs ← Functions. |
| لا تصل الإشعارات على iPhone | مفتاح APNs في Firebase (الخطوة 5.2). |
| يصل الإشعار بدون نغمة أو نافذة منبثقة على Android | إعدادات الجوال ← التطبيقات ← أسرتي ← الإشعارات ← «تنبيهات أسرتي»: تأكد أنها مفعّلة بصوت وبنافذة منبثقة (وضع «عدم الإزعاج» يكتمها). |
| فشل بناء iOS في خطوة Archive | تأكد أن مفتاح API بدور Admin وأن App ID موجود بتفعيل Push. |
