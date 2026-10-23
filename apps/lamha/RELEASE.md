# نشر «لمحة»

معرّف التطبيق: `sa.lamha.lamha` (أندرويد وآيفون، لا يتغير بعد أول رفع). مفتاح التوقيع وأسراره هي نفسها المستخدمة في «أسرتي» و«موعد».

## Google Play
1. **Actions ← «Lamha — Google Play bundle» ← Run workflow** على الفرع الرئيسي. ينتج `lamha-aab-N` في Artifacts (ملف `app-release.aab`).
2. [Play Console](https://play.google.com/console) ← Create app: الاسم «لمحة — ودجت الصلاة والإيداعات»، اللغة العربية، App، Free.
3. Testing ← Internal testing (أو Production مباشرة) ← Create new release ← ارفع `app-release.aab`.
4. Main store listing: النصوص والصور من `store/STORE_LISTING.md` و`store/play/`.
5. App content: الإجابات في `store/STORE_LISTING.md` (الخصوصية، الإعلانات، Data safety، التصنيف).
6. بعد أول رفع يدوي: مع السر `PLAY_SERVICE_ACCOUNT_JSON` تُرفع النسخ التالية بتفعيل خيار upload في الخطوة ١.

## App Store
ينتظر ودجت آيفون (الميزة ٤).
