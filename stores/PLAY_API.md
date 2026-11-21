# ربط Google Play Developer API

> ملاحظة: المستودع فيه سر `PLAY_SERVICE_ACCOUNT_JSON` مستخدم في أنظمة الرفع، أي أن حساب خدمة موجود. إن كان هو نفسه، تكفي الخطوة 3 (الصلاحيات) لكل تطبيق.

## 1) مشروع Google Cloud وتفعيل الـ API
1. افتح https://console.cloud.google.com (من المتصفح، بنفس حساب Play Console).
2. القائمة ☰ ← **IAM & Admin** ← **Create a project**، الاسم مثلاً `play-publisher` ← **Create**.
3. ابحث في الأعلى عن **Google Play Android Developer API** ← **Enable**.

## 2) حساب الخدمة ومفتاح JSON
1. ☰ ← **IAM & Admin** ← **Service Accounts** ← **Create service account**.
2. الاسم `play-publisher` ← **Create and continue** ← تخطَّ الأدوار (Roles) ← **Done**.
3. اضغط على الحساب ← تبويب **Keys** ← **Add key** ← **Create new key** ← **JSON** ← **Create**. ينزل ملف واحد؛ لا يمكن تنزيله مرة ثانية.
4. انسخ إيميل الحساب (ينتهي بـ `iam.gserviceaccount.com`).
5. لا ترسل الملف في محادثة ولا ترفعه للمستودع. الأفضل: أضفه سراً في GitHub (Settings ← Secrets and variables ← Actions ← `PLAY_SERVICE_ACCOUNT_JSON`، الصق محتواه كاملاً).

## 3) الدعوة في Play Console
1. https://play.google.com/console ← **Users and permissions** ← **Invite new users**.
2. الإيميل: إيميل حساب الخدمة.
3. تبويب **App permissions** ← **Add app** ← اختر التطبيقات (لمحة، أسرتي، مواعيد الرواتب والإجازات) ← فعّل:
   - **View app information (read-only)**
   - **Release apps to testing tracks**
   - (عند الحاجة لرفع صفحة المتجر: **Manage store presence**)
4. **Invite user** ← **Send invite**. قد يتأخر سريان الصلاحية حتى 24 ساعة.

## 4) السكربتات
المفتاح محلياً خارج المستودع فقط، مثل `~/.secrets/play-key.json` (`chmod 600`). أنماط أسماء المفاتيح مستثناة في `.gitignore` احتياطاً.

```sh
# حالة المسارات لكل التطبيقات في stores/apps.json (قراءة فقط)
PLAY_KEY_FILE=~/.secrets/play-key.json python3 .github/scripts/play_status.py

# رفع AAB على الاختبار المغلق (alpha) مع ملاحظات عربية (حتى 500 حرف)
PLAY_KEY_FILE=~/.secrets/play-key.json python3 .github/scripts/play_upload.py \
  sa.mawid.app app-release.aab notes_ar.txt --track=alpha [--draft] [--dry-run]
```
- `--dry-run`: يتحقق ثم يحذف التعديل؛ لا يتغير شيء في Play.
- في GitHub Actions يقرأ السكربتان السر `PLAY_SERVICE_ACCOUNT_JSON` بدل الملف.
- إذا كان التطبيق تحت مراجعة مُدارة (بعد رفض سياسة) يُحفظ التعديل ولا يُرسل للمراجعة تلقائياً؛ ترسله أنت من **Publishing overview**.

## 5) ما لا يقدر عليه الـ API (تابعه يدوياً في Play Console)
- **مخالفات السياسات ورسائل الرفض والإيقاف** (Policy status / Inbox): لا تظهر في الـ API.
- **حالة المراجعة البشرية** (In review / Rejected / Approved): الـ API يعطي حالة الإصدار في المسار (draft/inProgress/halted/completed) فقط، لا نتيجة المراجعة.
- **إرسال التعديلات للمراجعة** في التطبيقات تحت مراجعة مُدارة: من Publishing overview فقط.
- **App content**: سياسة الخصوصية، Data safety، التصنيف العمري، الجمهور المستهدف، الإعلانات، التطبيقات الحكومية/المالية.
- **أول رفع لتطبيق جديد**، وإنشاء التطبيق نفسه، وقبول الاتفاقيات.
- **ترقية الاختبار المغلق للإنتاج** وشرط 12 مختبراً × 14 يوماً، وطلب الوصول للإنتاج.
- **قوائم المختبرين في الاختبار المغلق** (المسار المُرقّى لا يقبل تعديلها عبر API، كما ظهر في سجل الرفع).
- **إحصاءات Android Vitals والتثبيتات بالتفصيل والطلبات المالية**: لها واجهات أخرى أو تصدير من Play Console.
- **الرد على المراجعات** ممكن عبر API (reviews)، لكنه غير مفعّل في سكربتاتنا.
