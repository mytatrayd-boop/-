# محاكي نافس 2026م
موقع مجاني للمعلم: اختبر طلابك، أصدر التقارير، أو اسحب الأسئلة واطبعها.

## التشغيل
افتح `web/index.html` في المتصفح مباشرة، أو: `npx serve web`.
## الاختبارات
`node --test test/core.test.mjs`
## إضافة أسئلة
عدّل `web/js/bank-*.js` (انظر CLAUDE.md). لا تُنسخ أسئلة من مصادر خارجية.
## النشر
نفّذ `sh apps/murtaqa/publish.sh` لنسخ الموقع إلى `docs/nafes-sim` (يُنشر عبر GitHub Pages: ‏`https://mytatrayd-boop.github.io/-/nafes-sim/`).
أي استضافة ملفات ثابتة تكفي. روابط الطلاب لا تعمل من `file://`.
