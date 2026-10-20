# مهارات القراءة لاختبارات نافس — موقع

موقع على Firebase: دخول للمعلم، ذاكرة على الخادم للطلاب والنتائج وملفات الأكسل، ودخول الطالب برقم السجل المدني.
الرابط بعد النشر: `https://<project-id>.web.app`

## إعداد مشروع Firebase (مرة واحدة، من console.firebase.google.com ← مشروع Nafs2026)

1. **Authentication** ← Get started ← Sign-in method: فعّل **Email/Password** و **Anonymous**.
2. **Firestore Database** ← Create database ← **Production mode** (الموقع الأقرب: `me-central2` الدمام إن توفر).
3. **Project settings** ← General ← Your apps ← أيقونة **</>** ← سجّل تطبيق ويب (بدون Hosting setup).
4. **Project settings** ← Service accounts ← **Generate new private key** ← ينزل ملف JSON.
5. في GitHub: المستودع ← Settings ← Secrets and variables ← Actions ← New repository secret
   الاسم `NAFS_FIREBASE_SERVICE_ACCOUNT` والقيمة محتوى ملف JSON كاملاً. ثم احذف الملف من جهازك.

## النشر
Actions ← **Nafs — deploy website** ← Run workflow. السكربت ينشر ثم يفحص الخطوات 1–3 ويخبرك بأي خطوة ناقصة.

## التطوير
```bash
npm ci
npm test                         # بناء + اختبارات المنطق والقواعد + تجربة كاملة في المتصفح (يحتاج Java 21)
npm run build && npm run emulators   # معاينة على http://localhost:5000
```
