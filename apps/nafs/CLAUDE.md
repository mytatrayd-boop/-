# مهارات القراءة لاختبارات نافس — عقل المشروع

- موقع ويب ثابت (ليس Flutter) على Firebase: Hosting + Auth + Firestore. انظر ARCHITECTURE.md وDECISIONS.md.
- الواجهة عربية RTL، والتصميم يطابق `design/original.html`.
- كل نص من المستخدم يُعرض بـ `textContent` — لا `innerHTML` لبيانات.
- أي تغيير في `firestore.rules` يحتاج اختباراً في `test/rules.test.mjs`.
- التشغيل والاختبار: `npm ci && npm test` (يحتاج Java 21 للمحاكيات). معاينة محلية: `npm run build && npm run emulators` ثم http://localhost:5000
- النشر: GitHub Actions ← «Nafs — deploy website» — لا تشغّله بدون موافقة المالك.
