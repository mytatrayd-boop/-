# أنظمة الرفع (Google Play / TestFlight)

المصدر: `.github/workflows/*.yml` على الفرع الافتراضي `claude/mobile-app-design-gxh65v`، ومطابقة لما يعيده `gh workflow view <file> --yaml` (تحقق 2026-10-24).
رقم البناء في الستة = `github.run_number` (لا يُعدَّل يدوياً).

## ملخص

| التطبيق | المنصة | الملف | ID | المُشغِّل | يدعم alpha؟ | حالة رفع Play |
|---|---|---|---|---|---|---|
| لمحة | Android | lamha-play.yml | 393655176 | يدوي | نعم (`track`) | `completed` ثابت |
| لمحة | iOS | lamha-ios.yml | 393643146 | يدوي + push | — | — |
| أسرتي | Android | asraty-android.yml | 370291878 | يدوي | نعم (`track`) | من المدخل `status` |
| أسرتي | iOS | asraty-ios.yml | 370291882 | يدوي | — | — |
| موعد | Android | mawid-play.yml | 379551945 | يدوي | نعم (`track`) | `completed` + `changesNotSentForReview: true` |
| موعد | iOS | mawid-ios.yml | 380260349 | يدوي | — | — |

الثلاثة الأندرويد تدعم alpha، فلا حاجة لطلب إضافة اختيار المسار.

---

## 1) لمحة — `lamha-play.yml` («Lamha — Google Play bundle»)
- **on:** `workflow_dispatch` فقط.
- **المدخلات:**
  | الاسم | الوصف | النوع | إلزامي | الافتراضي | الخيارات |
  |---|---|---|---|---|---|
  | upload | ارفع إلى Google Play (يتطلب PLAY_SERVICE_ACCOUNT_JSON وأن يكون أول رفع قد تم يدوياً) | boolean | لا | false | — |
  | track | مسار Play | choice | لا | internal | internal, alpha, beta |
- **يبني:** `apps/lamha` ← `.aab` موقّع، artifact `lamha-aab-<run>`؛ الرفع فقط إذا `upload=true`، الحزمة `sa.lamha.lamha`، **status: completed** (تحقق 2026-10-24: لم يعد draft).
- **خطوات قبل البناء:** flutter analyze + flutter test.
- **Secrets:** ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD, PLAY_SERVICE_ACCOUNT_JSON.
- **تنبيه:** بدون `-f upload=true` يُبنى فقط ولا يُرفع.

## 2) لمحة — `lamha-ios.yml` («Lamha — iOS (TestFlight)»)
- **on:** `push` على المسارات `apps/lamha/**`, `.github/workflows/lamha-ios.yml`, `.github/scripts/ios_signing.py` (بناء بلا توقيع فقط، لا رفع) + `workflow_dispatch` بلا مدخلات (يوقّع ويرفع).
- **يبني:** `apps/lamha` على macos-latest، التطبيق + ودجت `LamhaWidget`؛ التوقيع لـ `sa.lamha.lamha,sa.lamha.lamha.LamhaWidget` مع قدرة `APP_GROUPS`؛ رفع إلى App Store Connect (TestFlight). لا إرسال للمراجعة.
- **Secrets:** APPSTORE_API_KEY_P8, APPSTORE_API_KEY_ID, APPSTORE_API_ISSUER_ID, APPLE_TEAM_ID.
- **شرط:** App Group `group.sa.lamha.shared` مفعّلة للمعرّفين (apps/lamha/RELEASE.md).
- **ملاحظة متابعة:** تشغيلات push تظهر «success» دون رفع؛ الرفع الحقيقي هو تشغيلات `workflow_dispatch` فقط.

## 3) أسرتي — `asraty-android.yml` («Asraty — Android (Google Play internal testing)»)
- **on:** `workflow_dispatch` فقط.
- **المدخلات:**
  | الاسم | الوصف | النوع | إلزامي | الافتراضي | الخيارات |
  |---|---|---|---|---|---|
  | track | Play track | choice | لا | internal | internal, alpha, beta |
  | status | Release status (use 'draft' until the app has passed its first review) | choice | لا | completed | completed, draft |
- **يبني:** `asraty/app` ← `.aab` و`.apk` (مع `--dart-define-from-file=env.json`)، artifact `asraty-aab-<run>`، وينشئ GitHub Release (prerelease) باسم `asraty-android-<run>` فيه الملفان، ثم **يرفع تلقائياً إلى Play متى وُجد السر** (لا يوجد مدخل upload)؛ الحزمة `sa.asraty.app`.
- **لا يشغّل** analyze/test. صلاحية `contents: write` (لإنشاء الـ Release).
- **Secrets:** ASRATY_ENV_JSON (اختياري، وإلا env.prod.json)، ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD, PLAY_SERVICE_ACCOUNT_JSON.
- **تنبيه:** الافتراضي internal؛ للاختبار المغلق مرّر `-f track=alpha` صراحة.

## 4) أسرتي — `asraty-ios.yml` («Asraty — iOS (TestFlight)»)
- **on:** `workflow_dispatch` بلا مدخلات.
- **يبني:** `asraty/app` على macos-latest، توقيع `sa.asraty.app`، رفع إلى App Store Connect (TestFlight).
- **Secrets:** APPSTORE_API_KEY_P8, APPSTORE_API_KEY_ID, APPSTORE_API_ISSUER_ID, APPLE_TEAM_ID, ASRATY_ENV_JSON (اختياري).

## 5) موعد — `mawid-play.yml` («Mawid — Google Play bundle (internal testing)»)
- **on:** `workflow_dispatch` فقط.
- **المدخلات:**
  | الاسم | الوصف | النوع | إلزامي | الافتراضي | الخيارات |
  |---|---|---|---|---|---|
  | upload | ارفع إلى Google Play (يتطلب PLAY_SERVICE_ACCOUNT_JSON وأن يكون أول رفع قد تم يدوياً) | boolean | لا | false | — |
  | track | مسار Play | choice | لا | internal | internal, alpha, beta |
- **يبني:** `apps/mawid` ← analyze + test + `.aab`، artifact `mawid-aab-<run>`؛ الرفع إذا `upload=true`، الحزمة `sa.mawid.app`، `status: completed` مع `changesNotSentForReview: true` (التعديل يُحفظ في Play لكن **المالك يرسله للمراجعة من Publishing overview**).
- **Secrets:** ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD, PLAY_SERVICE_ACCOUNT_JSON.

## 6) موعد — `mawid-ios.yml` («Mawid — iOS (TestFlight)»)
- **on:** `workflow_dispatch` بلا مدخلات.
- **يبني:** `apps/mawid` على macos-latest، analyze + test، توقيع `sa.mawid.app`، رفع إلى App Store Connect (TestFlight).
- **Secrets:** APPSTORE_API_KEY_P8, APPSTORE_API_KEY_ID, APPSTORE_API_ISSUER_ID, APPLE_TEAM_ID.

---

## أوامر التشغيل الصحيحة (للاختبار فقط)
- لمحة أندرويد alpha: `gh workflow run lamha-play.yml -R mytatrayd-boop/- -f upload=true -f track=alpha`
- أسرتي أندرويد alpha: `gh workflow run asraty-android.yml -R mytatrayd-boop/- -f track=alpha -f status=completed`
- موعد أندرويد alpha: `gh workflow run mawid-play.yml -R mytatrayd-boop/- -f upload=true -f track=alpha`
- iOS (الثلاثة): `gh workflow run <lamha|asraty|mawid>-ios.yml -R mytatrayd-boop/-`

## ملاحظات أعطال سابقة
- أسرتي أندرويد: يفشل إن أُعيد تشغيل run بنفس الرقم (`a release with the same tag name already exists`) — لا تستخدم «Re-run»، شغّل تشغيلاً جديداً.
- iOS: قد يُلغى التشغيل إن لم يتوفر macOS runner (`job was not acquired by Runner`) — خطأ مؤقت، يُعاد مرة واحدة.

## صفحات المتجر — `store-listing.yml` («Store listing (Google Play + App Store)»)
- **on:** `workflow_dispatch` بالمدخلات: `app` (الاسم في `stores/apps.json`)، `store` (both/google/apple)، `mode` (dry-run/apply)، `build` (اختياري، رقم build آيفون).
- **جوجل:** `.github/scripts/play_listing.py`: العنوان والوصفان لكل لغة في `metadata/play/`، والأيقونة وصورة العرض واللقطات من `store/play/`. dry-run يتحقق من التعديل ويحذفه.
- **أبل:** `.github/scripts/appstore_listing.py`: الاسم والعنوان الفرعي والوصف والكلمات والنص الترويجي وروابط الدعم والخصوصية، واللقطات، وملاحظات المراجع، والتصنيف العمري، وربط build. على النسخة القابلة للتعديل فقط، ولا يرسل للمراجعة.
- **Secrets:** PLAY_SERVICE_ACCOUNT_JSON، APPSTORE_API_KEY_P8/ID/ISSUER_ID، واختياريًا ASC_REVIEW_FIRST_NAME/LAST_NAME/EMAIL/PHONE.
