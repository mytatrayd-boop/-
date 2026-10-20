# البنية

موقع ويب ثابت على **Firebase Hosting** + **Firebase Auth** + **Cloud Firestore** (الخطة المجانية Spark تكفي).

| الملف | الدور |
|---|---|
| `src/index.html` | الشاشات (نفس تصميم الأصل، Tailwind) |
| `src/app.js` | الدخول، القراءة والكتابة في Firestore، رفع الأكسل |
| `src/logic.js` | منطق نقي: قراءة صفوف الأكسل، تصحيح المحاولات، تقرير المهارات والتقدّم، CSV |
| `src/skills.js` | مهارات القراءة من وثيقة نواتج التعلم 2026 (الصفوف 3، 6، 9) |
| `src/templates.js` | نموذج اختبار جاهز لكل صف |
| `firestore.rules` | الصلاحيات |
| `scripts/build.mjs` | يبني `dist/` (esbuild + Tailwind، أسماء ملفات ببصمة المحتوى) |
| `scripts/deploy.mjs` | ينشر القواعد والموقع عبر REST بمفتاح حساب الخدمة، ثم يفحص جاهزية المشروع |

## البيانات
- `teachers/{uid}`: name, civilId, school, className, email, createdAt
- `teachers/{uid}/uploads/{id}`: name, size, type, data (base64), className, added, createdAt
- `students/{civilId}`: name, teacherUid, className, school, status, createdAt
- `tests/{id}`: teacherUid, title, className, grade (3|6|9), passage, questions [{skill, level, text, options}], skills, status (draft|published), createdAt, updatedAt
- `testKeys/{testId}`: teacherUid, answers — الإجابات الصحيحة، للمعلم فقط
- `attempts/{testId_civilId}`: testId, studentId, teacherUid, className, answers, submittedAt — تُكتب مرة واحدة

## الدخول والصلاحيات
- المعلم: Email/Password. يقرأ ويكتب ملفه وملفاته وطلابه فقط.
- الطالب: دخول مجهول (Anonymous) ثم قراءة مستند واحد برقم السجل المدني، وقراءة الاختبارات المنشورة، وإنشاء محاولة واحدة لكل اختبار (للاختبار المنشور لفصله ومعلمه فقط). لا يقرأ الإجابات الصحيحة.
- التصحيح والتقارير تُحسب في متصفح المعلم من المحاولات ومفاتيح الإجابات.
- لا قائمة طلاب لغير المعلم صاحبهم.

## إعدادات Firebase في الموقع
تُقرأ من `/__/firebase/init.json` الذي يقدمه Firebase Hosting تلقائياً — لا مفاتيح في الكود.
على `localhost` يتصل بالمحاكيات (مشروع `demo-nafs`).
