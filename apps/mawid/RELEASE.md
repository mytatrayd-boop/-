# نشر «موعد» للاختبار (Google Play — اختبار داخلي)

معرّف التطبيق: `sa.mawid.app` (لا يتغير بعد أول رفع). مفتاح التوقيع وأسراره هي نفسها المستخدمة في «أسرتي».

1. **Actions ← «Mawid — Google Play bundle» ← Run workflow** (اترك الخيارات كما هي). ينتج `mawid-aab-N` في Artifacts.
2. Play Console ← Create app (الاسم «موعد»، عربي، تطبيق، مجاني) ← Testing ← Internal testing ← Create new release ← ارفع `app-release.aab`.
3. Testers: أنشئ قائمة بإيميلات المختبرين وانسخ رابط الانضمام لهم. (الإيميلات تبقى في Play Console فقط، لا في المستودع لأنه عام.)
4. App content: سياسة الخصوصية (التطبيق بلا حسابات ولا خادم؛ الإشعارات محلية)، Ads: لا، Data safety: لا يجمع بيانات، الفئة العمرية: الجميع.
5. بعد أول رفع يدوي: لو أضفت السر `PLAY_SERVICE_ACCOUNT_JSON` يمكن رفع النسخ التالية بتفعيل خيار upload.
