# نشر «لمحة»

معرّف التطبيق: `sa.lamha.lamha` (أندرويد وآيفون، لا يتغير بعد أول رفع). مفتاح التوقيع وأسراره هي نفسها المستخدمة في «أسرتي» و«موعد».

## Google Play
1. **Actions ← «Lamha — Google Play bundle» ← Run workflow** على الفرع الرئيسي. ينتج `lamha-aab-N` في Artifacts (ملف `app-release.aab`).
2. [Play Console](https://play.google.com/console) ← Create app: الاسم «لمحة — ودجت الصلاة والإيداعات»، اللغة العربية، App، Free.
3. Testing ← Internal testing (أو Production مباشرة) ← Create new release ← ارفع `app-release.aab`.
4. Main store listing: النصوص والصور من `store/STORE_LISTING.md` و`store/play/`.
5. App content: الإجابات في `store/STORE_LISTING.md` (الخصوصية، الإعلانات، Data safety، التصنيف).
6. بعد أول رفع يدوي: مع السر `PLAY_SERVICE_ACCOUNT_JSON` تُرفع النسخ التالية بتفعيل خيار upload في الخطوة ١.

## App Store (آيفون مع الودجت)
معرّفا الحزمة: التطبيق `sa.lamha.lamha` والودجت `sa.lamha.lamha.LamhaWidget`، وتتشاركان App Group `group.sa.lamha.shared`. الأسرار نفسها المستخدمة في «أسرتي» و«موعد».

1. [developer.apple.com ← Identifiers](https://developer.apple.com/account/resources/identifiers) ← + ← **App Groups** ← `group.sa.lamha.shared`.
2. Identifiers ← افتح `sa.lamha.lamha` (أو أنشئه: App IDs ← App) ← فعّل **App Groups** ← Configure ← اختر `group.sa.lamha.shared` ← Save. كرّر لـ `sa.lamha.lamha.LamhaWidget`. (يُسجَّل المعرّفان ويُفعَّل App Groups تلقائياً في أول تشغيل إن لم يوجدا، لكن اختيار المجموعة يدوي: لا تتيحه واجهة Apple البرمجية.)
3. [App Store Connect](https://appstoreconnect.apple.com) ← Apps ← + ← New App ← iOS، الاسم «لمحة — ودجت الصلاة والإيداعات»، اللغة Arabic، Bundle ID `sa.lamha.lamha`، SKU `lamha-001`.
4. **Actions ← «Lamha — iOS (TestFlight)» ← Run workflow** على الفرع الرئيسي. بعد ١٠–٣٠ دقيقة يظهر الإصدار في TestFlight.
5. للنشر العام: صفحة التطبيق من `store/STORE_LISTING.md` واللقطات من `store/appstore/`، ثم اختر الإصدار وSubmit for Review.
