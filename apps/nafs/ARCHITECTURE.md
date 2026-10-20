# البنية

موقع ويب ثابت على **Firebase Hosting** + **Firebase Auth** + **Cloud Firestore** (الخطة المجانية Spark تكفي).

| الملف | الدور |
|---|---|
| `src/index.html` | الشاشات (نفس تصميم الأصل، Tailwind) |
| `src/app.js` | الدخول، القراءة والكتابة في Firestore، رفع الأكسل |
| `src/logic.js` | منطق نقي: قراءة صفوف الأكسل، الدرجة، الملخص، CSV |
| `firestore.rules` | الصلاحيات |
| `scripts/build.mjs` | يبني `dist/` (esbuild + Tailwind، أسماء ملفات ببصمة المحتوى) |
| `scripts/deploy.mjs` | ينشر القواعد والموقع عبر REST بمفتاح حساب الخدمة، ثم يفحص جاهزية المشروع |

## البيانات
- `teachers/{uid}`: name, civilId, school, className, email, createdAt
- `teachers/{uid}/uploads/{id}`: name, size, type, data (base64), className, added, createdAt
- `students/{civilId}`: name, teacherUid, className, school, status, score?, completedAt?, createdAt

## الدخول والصلاحيات
- المعلم: Email/Password. يقرأ ويكتب ملفه وملفاته وطلابه فقط.
- الطالب: دخول مجهول (Anonymous) ثم قراءة مستند واحد برقم السجل المدني. يكتب فقط `score` (0–100) و`status` و`completedAt`.
- لا قائمة طلاب لغير المعلم صاحبهم.

## إعدادات Firebase في الموقع
تُقرأ من `/__/firebase/init.json` الذي يقدمه Firebase Hosting تلقائياً — لا مفاتيح في الكود.
على `localhost` يتصل بالمحاكيات (مشروع `demo-nafs`).
