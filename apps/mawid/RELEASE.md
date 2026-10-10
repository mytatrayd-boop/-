# نشر «موعد» للاختبار (Google Play — اختبار داخلي)

معرّف التطبيق: `sa.mawid.app` (لا يتغير بعد أول رفع). مفتاح التوقيع وأسراره هي نفسها المستخدمة في «أسرتي».

1. **Actions ← «Mawid — Google Play bundle» ← Run workflow** (اترك الخيارات كما هي). ينتج `mawid-aab-N` في Artifacts.
2. Play Console ← Create app (الاسم «موعد»، عربي، تطبيق، مجاني) ← Testing ← Internal testing ← Create new release ← ارفع `app-release.aab`.
3. Testers: أنشئ قائمة بإيميلات المختبرين وانسخ رابط الانضمام لهم. (الإيميلات تبقى في Play Console فقط، لا في المستودع لأنه عام.)
4. App content: سياسة الخصوصية (التطبيق بلا حسابات ولا خادم؛ الإشعارات محلية)، Ads: لا، Data safety: لا يجمع بيانات، الفئة العمرية: الجميع.
5. بعد أول رفع يدوي: لو أضفت السر `PLAY_SERVICE_ACCOUNT_JSON` يمكن رفع النسخ التالية بتفعيل خيار upload.

# نشر «موعد» على آيفون (TestFlight ثم App Store)

معرّف الحزمة: `sa.mawid.app` (نفس أندرويد). الأسرار نفسها المستخدمة في «أسرتي» (`APPSTORE_API_KEY_P8`، `APPSTORE_API_KEY_ID`، `APPSTORE_API_ISSUER_ID`، `APPLE_TEAM_ID`) — التفاصيل في `asraty/docs/RELEASE.md` الخطوة 5.

1. [developer.apple.com ← Identifiers](https://developer.apple.com/account/resources/identifiers) ← + ← App IDs ← Bundle ID `sa.mawid.app` (لا يحتاج Push؛ التنبيهات محلية).
2. [App Store Connect](https://appstoreconnect.apple.com) ← Apps ← + ← New App ← iOS، الاسم «مواعيد الرواتب والإجازات»، اللغة Arabic، Bundle ID `sa.mawid.app`، SKU مثل `mawid-001`.
3. **Actions ← «Mawid — iOS (TestFlight)» ← Run workflow**. بعد 10–30 دقيقة يظهر الإصدار في TestFlight.
4. للنشر العام: صفحة التطبيق (وصف، كلمات مفتاحية، لقطات شاشة آيفون 6.9 بوصة)، سياسة الخصوصية: `<رابط خادم أسرتي>/mawid-privacy` (تُنشر مع «Asraty — deploy backend»)، App Privacy: «لا يجمع بيانات»، ثم اختر الإصدار وSubmit for Review.
- التطبيق لآيفون فقط (لا يحتاج لقطات آيباد). سؤال التشفير مضبوط تلقائياً (لا تشفير خاص).
