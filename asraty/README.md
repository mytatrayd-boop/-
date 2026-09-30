# أسرتي (Asraty)

تطبيق مهام البيت للأسرة بالنقاط والمسابقات والمكافآت — Flutter (iOS + Android) مع Firebase.

| المجلد | المحتوى |
|---|---|
| `app/` | تطبيق Flutter (عربي RTL، Riverpod، go_router) |
| `functions/` | الخادم بـ TypeScript (يُنشر على Vercel): الدخول بكود البريد، الصلاحيات، النقاط، المسابقات، الإشعارات، وصفحتا الخصوصية وحذف الحساب في `public/` |
| `firestore.rules` | قواعد الأمان (العميل يقرأ فقط، وكل كتابة عبر الخادم) |
| `design/`, `docs/SPEC.md` | النموذج الأولي والمواصفات |
| `docs/RELEASE.md` | **دليل النشر التجريبي على Google Play و TestFlight** |
| `docs/STORE_LISTING.md` | نصوص صفحة المتجر |

## التشغيل محلياً

```bash
# التطبيق بالتجربة السريعة فقط (بدون Firebase)
cd app && flutter run

# مع محاكيات Firebase
cd functions && npm ci && npm run dev                  # في نافذة: المحاكيات + الخادم على :5055
cd app && flutter run --dart-define-from-file=env.json --dart-define=EMULATOR_HOST=10.0.2.2
# أكواد الدخول تظهر في سجل المحاكي وفي مجموعة devMail (http://localhost:4000)
```

## الاختبارات

```bash
cd app && flutter analyze && flutter test
cd functions && npm test && npm run test:rules && npm run test:api   # المحاكيات تحتاج Java
```

## النشر
اتبع [`docs/RELEASE.md`](docs/RELEASE.md). البناء والرفع يتمّان من GitHub Actions:
«Asraty — deploy backend»، «Asraty — Android»، «Asraty — iOS (TestFlight)».
