# عدسة البُن (BrewLens) — عقل المشروع

قواعد الشركة في `/home/user/-/CLAUDE.md` تنطبق هنا.

تطبيق يقيّم **مظهر** كوب القهوة (إسبريسو، V60، فرنش بريس) من صورة عبر الذكاء الاصطناعي، ويربطه بمقهى يكتب المستخدم اسمه ويحفظ موقعه، مع سجل ومفضلة ومشاركة بطاقة. تحليلان مجاناً يومياً ثم اشتراك.

## المراجع
- `IDEA.md` فكرة المالك. `SPEC.md` الميزات ومعايير القبول (المرجع للسلوك).
- `ARCHITECTURE.md` التصميم التقني وخطة البناء. `DESIGN.md` الشكل.
- `DECISIONS.md` القرارات (D14: لا Google Places). `STATUS.md` حالة العمل.

## التقنية
- Flutter (أندرويد وآيفون)، Riverpod 3 بلا توليد كود، go_router، ARB للترجمة (القالب `app_ar.arb`).
- Supabase (مصادقة، Postgres+RLS، تخزين خاص، Edge Functions). Gemini عبر الدالة `analyze` فقط. RevenueCat للاشتراك.
- معرّف التطبيق: `com.mytatrayd.brewlens`.

## الأوامر (من داخل `apps/brewlens/`)
- Flutter stable: `flutter` من PATH أو `/home/user/flutter/bin/flutter`؛ البيئة قد تُمسح، فإن لم يوجد يُعاد التثبيت.
- `flutter pub get` ثم `flutter analyze` ثم `flutter test`.
- وضع العرض (بلا مفاتيح): `flutter run` أو `flutter build apk --release`.
- البناء الحقيقي: `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=REVENUECAT_GOOGLE_KEY=...` والقيم من `.env` أو أسرار GitHub فقط، أو عبر `tool/build_release.sh` (يفشل إن غاب متغير).
- CI: `.github/workflows/brewlens-android.yml` يبني APK بوضع العرض ويرفعه artifact.

## قواعد الكود
- كل اتصال بالخلفية عبر واجهات `lib/domain/repositories/` بتنفيذين: `lib/backend/demo/` و`lib/backend/supabase/`. الشاشات لا تستورد supabase ولا purchases مباشرة.
- لا تسمِّ أي مجلد `data/`: `.gitignore` الجذري يستثنيه.
- لا نص ثابت في الشاشات؛ كل نص في `app_ar.arb` و`app_en.arb`. استخدم `EdgeInsetsDirectional` و`AlignmentDirectional` لا left/right.
- الدرجة اسمها دائماً «تقييم المظهر»، ولا تظهر كلمة «الطعم» معها.
- الحد اليومي يُفرض على الخادم فقط؛ التطبيق يعرض ما يعيده الخادم (المحاكاة المحلية في وضع العرض فقط).
- رسائل الأخطاء من رموز `AppFailure` عبر الترجمة، لا من نص الخادم أو النموذج.
- لا مفاتيح ولا أسرار في الكود أو git. مفتاح Gemini وسر webhook في Supabase Secrets فقط.
- أقل بيانات: لا اسم عرض، لا موقع على التقييم، الموقع يُقرأ مرة فقط عند ضغط «حفظ موقعي». لا أدوات تتبع.
- الخرائط برابط Google Maps URLs المجاني فقط؛ لا Places ولا أي مفتاح خرائط (D14).
- كل جدول جديد يُفعَّل عليه RLS في نفس ملف الترحيل، مع اختبار لمستخدمين اثنين.
- لا يُرفع أي بناء في وضع العرض لأي متجر. لا نشر لـ Supabase أو المتاجر بدون موافقة المالك.
- كل ميزة معها اختبارها؛ `flutter analyze` و`flutter test` نظيفان قبل كل commit.
