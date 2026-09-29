# دليل النشر التجريبي — Google Play و App Store (TestFlight)

هذا الدليل يوصلك من الكود إلى نسخة تجريبية على جوالات أسرتك. **لا تحتاج جهاز Mac**: البناء يتم على GitHub Actions (خوادم Linux و macOS مجانية للمستودعات العامة، ومحدودة الدقائق للخاصة).

> يمكنك رفع نسخة Android تجريبية **قبل** إعداد Firebase: التطبيق يعمل حينها بـ«التجربة السريعة» فقط (بيانات على الجهاز). لتسجيل الدخول الحقيقي بالبريد أكمل الخطوات 1–3.

## ما ستحتاجه

| الحساب | التكلفة | لماذا |
|---|---|---|
| Google Firebase (خطة Blaze) | شبه مجاني لعدد قليل من الأسر | الخادم وقاعدة البيانات |
| Resend.com | مجاني حتى 3000 رسالة/شهر | إرسال أكواد الدخول |
| Google Play Console | 25$ مرة واحدة | نشر Android |
| Apple Developer Program | 99$ سنوياً | نشر iPhone |

كل المفاتيح تُحفظ في **GitHub → المستودع → Settings → Secrets and variables → Actions → New repository secret**. لا تضعها في الكود أبداً.

---

## 1) Firebase

1. من [console.firebase.google.com](https://console.firebase.google.com) أنشئ مشروعاً (مثلاً `asraty-app`)، ثم فعّل خطة **Blaze** (مطلوبة لـ Cloud Functions).
2. **Firestore Database** ← Create database ← Production mode ← الموقع `me-central2 (Dammam)`.
3. **Storage** ← Get started ← نفس الموقع.
4. **Authentication** ← Get started (لا تحتاج تفعيل أي مزوّد — الدخول بكود البريد يتم عبر الخادم).
5. **Project settings ← General ← Your apps**:
   - أضف تطبيق **Android** بالمعرّف `sa.asraty.app`.
   - أضف تطبيق **iOS** بالمعرّف `sa.asraty.app`.
   - لا تحتاج تنزيل `google-services.json` ولا `GoogleService-Info.plist`؛ انسخ فقط القيم التالية.
6. أنشئ سر GitHub باسم **`ASRATY_ENV_JSON`** بهذا الشكل (القيم من صفحة إعدادات المشروع):

```json
{
  "FIREBASE_API_KEY": "AIza...",
  "FIREBASE_PROJECT_ID": "asraty-app",
  "FIREBASE_MESSAGING_SENDER_ID": "1234567890",
  "FIREBASE_STORAGE_BUCKET": "asraty-app.firebasestorage.app",
  "FIREBASE_ANDROID_APP_ID": "1:1234567890:android:abc...",
  "FIREBASE_IOS_APP_ID": "1:1234567890:ios:def...",
  "IOS_BUNDLE_ID": "sa.asraty.app",
  "FUNCTIONS_REGION": "me-central2",
  "PRIVACY_URL": "https://asraty-app.web.app/privacy"
}
```

7. **صلاحية توقيع رموز الدخول** (مهمة، وإلا يفشل التحقق من الكود): في [Google Cloud Console ← IAM](https://console.cloud.google.com/iam-admin/iam) اختر مشروعك، وابحث عن الحساب `...-compute@developer.gserviceaccount.com`، واضغط ✎ وأضف الدور **Service Account Token Creator**.

## 2) البريد (Resend)

1. سجّل في [resend.com](https://resend.com)، ثم **Domains ← Add domain** وأضف نطاقاً تملكه (مثل `asraty.app`) وأكمل سجلات DNS. بدون نطاق موثّق لا يرسل Resend إلا لبريدك أنت.
2. **API Keys ← Create** وانسخ المفتاح.
3. أسرار GitHub:
   - `RESEND_API_KEY` = المفتاح.
   - `MAIL_FROM` = مثلاً `أسرتي <no-reply@asraty.app>`.

## 3) نشر الخادم (Cloud Functions + قواعد الأمان + صفحة الخصوصية)

**الطريقة الأسهل (من GitHub):**
1. في Google Cloud Console ← IAM ← Service Accounts أنشئ حساباً باسم `github-deploy` وامنحه الأدوار: **Firebase Admin**، **Cloud Functions Admin**، **Service Account User**، **Secret Manager Admin**، **Cloud Build Editor**، **Artifact Registry Administrator**. ثم Keys ← Add key ← JSON.
2. أسرار GitHub: `FIREBASE_SERVICE_ACCOUNT_JSON` (محتوى ملف JSON كاملاً) و `FIREBASE_PROJECT_ID`.
3. **Actions ← «Asraty — deploy Firebase backend» ← Run workflow.**

**أو من جهازك:** `npm i -g firebase-tools && firebase login`، ثم داخل مجلد `asraty/`:
```bash
firebase use --add            # اختر مشروعك
firebase functions:secrets:set RESEND_API_KEY
echo 'MAIL_FROM=أسرتي <no-reply@asraty.app>' > functions/.env
firebase deploy
```

بعد النشر تظهر سياسة الخصوصية على `https://<project>.web.app/privacy` وصفحة حذف الحساب على `https://<project>.web.app/delete-account` — ستحتاجهما في المتجرين.

> إذا ظهر خطأ أن المنطقة `me-central2` غير متاحة للـ Functions، غيّرها إلى `europe-west1` في `functions/src/config.ts` وفي `FUNCTIONS_REGION` داخل `ASRATY_ENV_JSON`.

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
7. في TestFlight: أجب على سؤال التشفير (تم ضبطه تلقائياً: لا تشفير خاص)، ثم **Internal Testing ← +** وأضف إيميلات Apple ID لأسرتك (حتى 100 شخص، بدون مراجعة). يثبّتون تطبيق **TestFlight** من App Store ثم يقبلون الدعوة.
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
| «تعذّر الاتصال» عند طلب الكود | تأكد أن الخادم منشور (الخطوة 3) وأن `FUNCTIONS_REGION` مطابق. |
| يصل الكود لكن التحقق يفشل بخطأ عام | صلاحية **Service Account Token Creator** (الخطوة 1.7). |
| لا يصل البريد | نطاق Resend غير موثّق أو `MAIL_FROM` لا يطابق النطاق. راجع Firebase ← Functions ← Logs. |
| لا تصل الإشعارات على iPhone | مفتاح APNs في Firebase (الخطوة 5.2). |
| يصل الإشعار بدون نغمة أو نافذة منبثقة على Android | إعدادات الجوال ← التطبيقات ← أسرتي ← الإشعارات ← «تنبيهات أسرتي»: تأكد أنها مفعّلة بصوت وبنافذة منبثقة (وضع «عدم الإزعاج» يكتمها). |
| فشل بناء iOS في خطوة Archive | تأكد أن مفتاح API بدور Admin وأن App ID موجود بتفعيل Push. |
