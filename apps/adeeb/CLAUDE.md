# الأديب الذكي (Adeeb AI) — عقل المشروع

قواعد الشركة في `/home/user/-/CLAUDE.md` تنطبق هنا أيضاً. اعمل داخل `apps/adeeb/` فقط.

## التطبيق
تطبيق جوال مجاني لقراءة كتب الأدب العربي التراثي والبحث فيها والاستماع إليها دون إنترنت، مع «اسأل الأديب»: إجابة من نصوص الكتب فقط باقتباس متحقَّق ومصدر قابل للنقر. بلا حساب ولا إعلانات ولا اشتراكات. العربية RTL أولاً ثم الإنجليزية.

المراجع: `SPEC.md` (الميزات والقبول)، `ARCHITECTURE.md` (التصميم)، `DECISIONS.md` (القرارات Dn)، `STATUS.md` (الحالة).

## التقنية
- Flutter stable / Dart 3، أندرويد أولاً ثم آيفون. Riverpod 3 بلا توليد كود، go_router، gen-l10n (ARB).
- تخزين محلي: `sqlite3` (مضمّن) + FTS5 على نص مطبَّع. صوت: `flutter_tts` + `audio_service` + `audio_session`.
- الكتب: JSON مضغوط في `library/` تُجلب من GitHub raw (ARCHITECTURE §4، §9).
- الخادم الوسيط: Cloudflare Worker في `worker/` (TypeScript). **لا Firebase بأي شكل** (D1، D2).
- قائمة الحزم المعتمدة: ARCHITECTURE §3. لا تُضف حزمة إلا مستقرة ومشهورة بترخيص MIT/BSD/Apache، وسجّل السبب في DECISIONS.md.

## الأوامر
التطبيق (من `apps/adeeb/`):
```
cp config/app_config.example.json config/app_config.json   # مرة واحدة، غير مرفوع
flutter pub get
flutter analyze        # يجب: No issues found
flutter test           # يجب: All tests passed
flutter run --dart-define-from-file=config/app_config.json
flutter build apk --release --dart-define-from-file=config/app_config.json
```
البيانات (من `apps/adeeb/library/tools/`): `dart pub get && dart test && dart run bin/validate.dart ../`
الخادم (من `apps/adeeb/worker/`):
```
npm ci
npm test               # vitest، Gemini مُحاكى، لا يحتاج مفتاحاً
npx wrangler dev       # يقرأ .dev.vars (غير مرفوع، انسخه من .dev.vars.example)
npx wrangler deploy --dry-run
```
`wrangler deploy` الفعلي و`wrangler secret put` يُشغّلهما المالك أو سير CI يدوي بموافقته فقط.

## المفاتيح والأسرار
- لا مفاتيح ولا كلمات مرور ولا رموز في أي ملف مرفوع، ولا تطلبها من المالك في المحادثة.
- مفتاح Gemini و`DEVICE_SALT` و`IP_SALT`: Cloudflare Secrets فقط. رمز نشر Cloudflare: سر GitHub `CLOUDFLARE_API_TOKEN`.
- محلياً: `worker/.dev.vars` و`config/app_config.json` و`.env` — كلها في `.gitignore`. التطبيق لا يحمل أي سر؛ إعداده عناوين عامة فقط.
- قبل أي commit: لا يظهر `AIza` أو `GEMINI_API_KEY=` بقيمة في الفرق.

## قواعد الكود
- كل نص واجهة في `lib/l10n/app_ar.arb` و`app_en.arb`؛ لا نصوص مكتوبة داخل الواجهة. `EdgeInsetsDirectional` و`start/end` لا `left/right`. نص الكتب دائماً RTL حتى في الواجهة الإنجليزية.
- `lib/text/` ومنطق `library/` و`ask/` وتقسيم الصوت: Dart صافٍ بلا Flutter، مع اختبارات وحدة.
- التطبيع العربي دالة واحدة (`lib/text/arabic_normalizer.dart`) للفهرسة والاستعلام والتحقق من الاقتباس؛ لا تكررها.
- معرّفات الفقرات ثابتة إلى الأبد؛ لا تغيّر معرّفاً منشوراً، استخدم `redirects`.
- لا تُعرض إجابة ذكية بلا اقتباس تحقق منه `quote_verifier`، والاقتباس المعروض من النص المحلي لا من نص النموذج.
- تعليمات Gemini على الخادم فقط. الخادم لا يسجّل نص السؤال ولا الفقرات ولا IP ولا المعرّف.
- الخصوصية: لا تحليلات، لا تقارير أعطال، لا إعلانات، لا معرّفات نظام. الشبكة: GitHub raw والخادم فقط، HTTPS فقط.
- لا تكتب نصاً تراثياً من الذاكرة. الكتب من ويكي مصدر/الشاملة عبر أدوات `library/tools` ووكيل `heritage-texts`، بلا حواشي ومقدمات المحققين، مع تسجيل المصدر في `library/SOURCES.md`.
- لا تسمِّ أي مجلد `data` (مستثنى في `.gitignore` الجذري). لا `build/` ولا `node_modules/` في git.

## اختبارات إلزامية قبل قول «يعمل»
- `flutter analyze` بلا مشكلات و`flutter test` ناجح؛ وعند تعديل الخادم `npm test`؛ وعند تعديل الكتب مدقق `library/tools`.
- كل تغيير في التطبيع أو البحث أو المسترجع أو مدقق الاقتباس أو عدّادات الخادم يأتي مع اختبار.
- ما لا يُختبر هنا (جهاز حقيقي، الشاشة المقفلة، النشر على Cloudflare) يُذكر صراحة أنه لم يُختبر.

## ممنوع بلا موافقة المالك الصريحة
نشر الخادم لأول مرة، أي نشر عام أو Release عام، إنشاء المستودع المنفصل، أي دفع (مثل حساب Google Play)، حذف بيانات.
