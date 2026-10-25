# المعمارية — BrewLens («عدسة البُن»)

> المصادر: SPEC.md، DECISIONS.md (D1–D14، وقرارات المعماري D15–D23). آخر تحديث: 2026-10-25.
> F6 يتبع D14: لا Google Places ولا قائمة مقاهٍ قريبة. المستخدم يكتب اسم المقهى، ويحفظ موقعه GPS اختيارياً، ويفتحه في خرائط جوجل برابط.

## 1. القرار الأساسي
- **Flutter** تطبيق واحد لأندرويد وآيفون، العربية RTL افتراضياً ثم الإنجليزية.
- **Supabase** للخلفية (D2): مصادقة بالبريد، Postgres مع RLS، تخزين خاص، Edge Functions (Deno/TypeScript).
- **Gemini Flash** خلف Edge Function فقط (D1). لا مفتاح ذكاء اصطناعي ولا مفتاح خرائط في التطبيق.
- **RevenueCat** للاشتراك (F9)، خلف واجهة، ومؤجل لما بعد التجريبية.
- **وضع العرض:** كل اتصال بالخلفية يمر عبر واجهات (repositories) لها تنفيذان: `Demo` (محلي، بلا إنترنت) و`Supabase`. الاختيار وقت البناء بـ `--dart-define`.

## 2. اختيار التنفيذ (Demo أو Supabase)
```
SUPABASE_URL و SUPABASE_ANON_KEY موجودان  -> تنفيذ Supabase
أحدهما غائب                                -> وضع العرض (Demo) + شريط «نسخة عرض» أعلى كل شاشة
REVENUECAT_GOOGLE_KEY / REVENUECAT_APPLE_KEY غائب (مع Supabase) -> الشراء معطّل برسالة «غير متاح حالياً»
```
- القيم تُقرأ مرة في `lib/app/env.dart` عبر `String.fromEnvironment`. لا قيم افتراضية حقيقية في الكود.
- `main.dart` يبني `ProviderScope` مع `overrides` لمزوّدات الواجهات حسب الوضع. الشاشات لا تعرف أي تنفيذ يعمل.
- `Supabase.initialize` لا يُستدعى في وضع العرض إطلاقاً.
- مفتاح `anon` ليس سراً (محمي بـ RLS)، لكنه لا يُكتب في الكود ولا git؛ يُمرَّر من أسرار GitHub أو `.env` محلي مستثنى.
- البناء للمتاجر يمر عبر `tool/build_release.sh` الذي يفشل إن غاب أي متغير (F1 معيار 7). سير GitHub للتجريبية يبني بلا متغيرات = وضع العرض.

## 3. الواجهات (lib/domain/repositories/)
| الواجهة | المسؤولية | Demo | Supabase |
|---|---|---|---|
| `AuthRepository` | تسجيل، دخول، استعادة كلمة المرور، خروج، تدفق حالة الجلسة | يقبل أي بريد صالح وكلمة ≥ 6؛ الجلسة في shared_preferences | `supabase.auth` |
| `AnalysisRepository` | `analyze(bytes, type, lang)` و`usage()` | تأخير ~2 ث، نتيجة ثابتة، مفتاح «محاكاة صورة مرفوضة»، حد 2 يومياً محلياً بتوقيت الرياض | Edge Functions `analyze` و`usage` |
| `ReviewsRepository` | حفظ/قراءة على دفعات/تعديل/حذف التقييم وصورته | JSON في shared_preferences + الصورة في مجلد التطبيق (path_provider) | جدول `coffee_reviews` + تخزين `review-images` |
| `ShopsRepository` | إنشاء مقهى (اسم + إحداثيات اختيارية)، قائمة مقاهي المستخدم، المفضلة ومتوسطاتها | محلي، مع 5 مقاهٍ نموذجية في الرياض محفوظة مسبقاً | جداول `shops` و`favorites` |
| `PurchasesRepository` | العروض والأسعار، شراء، استعادة، حالة الاشتراك | الأسعار ثابتة من D8، الشراء يعرض «غير متاح في نسخة العرض»، مفتاح «محاكاة مشترك» في الإعدادات | RevenueCat (`purchases_flutter`) |
| `AccountRepository` | حذف الحساب | يمسح كل البيانات المحلية | Edge Function `delete_account` |

- خدمات بلا خلفية (تنفيذ واحد): `LocationService` (geolocator)، `MapsLauncher` (url_launcher)، `ShareCardService` (RepaintBoundary → PNG → share_plus)، `ImageSource` (image_picker).
- الأخطاء: كل تنفيذ يحوّل أخطاءه إلى `AppFailure` بأحد الرموز: `unauthorized`، `limit_reached`، `fair_use_reached`، `invalid_image(reason)`، `analysis_failed`، `timeout`، `service_paused`، `image_too_large`، `offline`، `save_failed`، `purchase_unavailable`. الشاشات تعرض النص من ملفات الترجمة حسب الرمز فقط.

## 4. نموذج البيانات في التطبيق (lib/domain/models/)
كلاسات Dart عادية غير قابلة للتعديل مع `fromJson/toJson` يدوي (بلا توليد كود):
- `CoffeeType`: `espresso`، `v60`، `frenchPress` (`isVisualLimited` لـ V60 وفرنش بريس).
- `AnalysisResult`: `imageValid`، `reason`، `score` (0–10 بخطوة 0.5)، `notes` (3)، `tip`، `usage`. التحقق من العقد (SPEC §3) في `fromJson`.
- `Usage`: `remaining`، `limit`، `period` (`day`/`month`)، `isSubscriber`.
- `Review`: `id`، `coffeeType`، `imagePath`، `aiScore`، `aiNotes` (notes + tip)، `userRating?`، `userNotes?`، `shopId?`، `createdAt`.
- `Shop`: `id`، `name`، `latitude?`، `longitude?`، `isFavorite`، ومتوسطات `avgRating?`/`avgScore?` للعرض.

## 5. إدارة الحالة والتنقل
- **Riverpod 3** (`flutter_riverpod`) بلا توليد كود: `Provider` للواجهات، `Notifier/AsyncNotifier` للحالة (الجلسة، العدّاد، السجل، المفضلة، اللغة). نفس اختيار adeeb وdurur.
- **go_router**: `redirect` يعتمد على حالة الجلسة (F2 معيار 6). المسارات:
  `/login`، `/signup`، `/forgot`، `/` (الرئيسية)، `/capture`، `/result`، `/shop-picker`، `/history` (تبويبا السجل والمفضلة)، `/review/:id`، `/paywall`، `/settings`، `/delete-account`.
- اللغة: `localeProvider` محفوظ في shared_preferences؛ الافتراضي العربية إن كانت لغة الجهاز غير مدعومة (F1 معيار 2).

## 6. التدفقات الرئيسية
**التحليل (F4/F5):**
1. الكاميرا: اختيار النوع، ثم `image_picker` (كاميرا النظام بمعاينتها المباشرة، أو المعرض) مع `maxWidth: 1024, maxHeight: 1024, imageQuality: 80` (≤ 1024 بكسل ونحو 300 ك.ب) — بلا حزمة ضغط إضافية.
2. `AnalysisRepository.analyze` → الخادم يتحقق ويحجز محاولة ويستدعي Gemini ويعيد النتيجة والمتبقي.
3. النتيجة تبقى في الذاكرة حتى «حفظ»: يُرفع الملف ثم يُنشأ السجل. الصور المرفوضة لا تُرفع.

**المقهى (F6 حسب D14):**
- «اختيار المقهى» يعرض مقاهي المستخدم السابقة (بحث بالاسم) + «مقهى جديد»: حقل اسم وزر «حفظ موقعي الحالي» (اختياري).
- الموقع يُطلب فقط عند الضغط على الزر: قراءة واحدة، دقة متوسطة، مهلة 10 ث. الرفض أو المهلة لا يمنع الحفظ بالاسم فقط.
- «فتح في خرائط جوجل»: رابط Google Maps URLs المجاني بلا مفتاح:
  `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>` أو `query=<الاسم مُرمَّزاً>` عند غياب الإحداثيات، عبر `url_launcher` بوضع `externalApplication`.

**المشاركة (F8):** ويدجت البطاقة داخل `RepaintBoundary` (4:5) → `toImage` → PNG في الذاكرة → `SharePlus` بـ `XFile.fromData`. لا روابط تخزين ولا إحداثيات ولا بريد.

**حذف الحساب (F10):** Edge Function بمفتاح الخدمة: تحذف ملفات `review-images/{uid}/` ثم `auth.admin.deleteUser(uid)`، والجداول تُحذف بـ `on delete cascade`. العملية قابلة للإعادة بأمان إن فشلت في المنتصف.

## 7. الخادم (supabase/)
### 7.1 الجداول (`supabase/migrations/0001_init.sql`)
| الجدول | الأعمدة | RLS |
|---|---|---|
| `profiles` | `id uuid pk → auth.users on delete cascade`، `is_subscriber bool default false`، `is_reviewer bool default false`، `created_at` | قراءة: صاحبه فقط. لا insert/update/delete من العميل (يُنشأ بمشغّل `on auth.users insert`). |
| `shops` | `id`، `user_id → auth.users cascade`، `name text (1–80)`، `latitude/longitude numeric null` (بقيود النطاق)، `created_at` | كل العمليات: `user_id = auth.uid()` (D19). |
| `coffee_reviews` | `id`، `user_id cascade`، `shop_id → shops on delete set null`، `coffee_type check (espresso,v60,french_press)`، `image_path`، `ai_score numeric check 0–10`، `ai_notes jsonb`، `user_rating smallint check 1–5 null`، `user_notes text (≤ 500)`، `created_at` | كل العمليات: صاحبه فقط. |
| `favorites` | `user_id`، `shop_id`، `created_at`، `primary key (user_id, shop_id)` | صاحبه فقط، والمقهى يجب أن يكون للمستخدم نفسه. |
| `usage_daily` | `user_id`، `day date` (تاريخ الرياض)، `count int`، `pk (user_id, day)` | قراءة: صاحبه فقط. الكتابة عبر دوال الخادم فقط. |
| `app_config` | `key text pk`، `value jsonb` (مفاتيح SPEC §4) | لا وصول من العميل (service role فقط). |

- لا `display_name` ولا موقع في `coffee_reviews` (أقل بيانات، D20). لا `place_id` (D14).
- عرض `shop_stats` (`security_invoker`) يحسب متوسط نجوم ومظهر المستخدم لكل مقهى.
- دالتان SQL (`security definer`، تُنفَّذ بـ service role فقط):
  - `reserve_analysis(uid)`: تقفل صف اليوم (`select … for update`) وتتحقق من الحد (المجاني: يومي/شهري حسب `app_config`؛ المشترك: 20 يوم و300 شهر معاً؛ المراجع: بلا حد) ثم تزيد العدّاد وتعيد المتبقي أو `limit_reached`/`fair_use_reached`. هذا يحقق F4 معيار 5 (طلبان متزامنان).
  - `release_analysis(uid, day)`: تنقص العدّاد عند الرفض أو الفشل أو المهلة.
  - اليوم = `(now() at time zone 'Asia/Riyadh')::date`، والشهر = `date_trunc('month', …)` بنفس المنطقة.
- التخزين: bucket خاص `review-images`، المسار `{uid}/{review_id}.jpg`، سياسات `storage.objects` تسمح فقط عندما `(storage.foldername(name))[1] = auth.uid()::text`. لا روابط عامة؛ العرض بروابط موقّعة قصيرة العمر.

### 7.2 الدوال (`supabase/functions/`)
| الدالة | الوظيفة |
|---|---|
| `analyze` | تتحقق من JWT (401 وإلا) → `ai_enabled` → حجم الصورة (≤ 1.5 م.ب، وإلا `image_too_large`) → `reserve_analysis` → Gemini (`ai_model` و`prompt` من `app_config`، response schema، مهلة 25 ث، إعادة مرة عند JSON غير صالح) → `release_analysis` عند `image_valid=false`/فشل/مهلة → الرد حسب SPEC §3 مع المتبقي. |
| `usage` | تعيد المتبقي والحد ونوع الفترة فقط. |
| `delete_account` | انظر §6. |
| `revenuecat_webhook` | تتحقق من سر `Authorization` ثم تحدّث `profiles.is_subscriber`؛ `app_user_id` في RevenueCat = `auth.uid()`. |

- الأسرار في Supabase Secrets فقط: `GEMINI_API_KEY`، `REVENUECAT_WEBHOOK_SECRET`. `SUPABASE_SERVICE_ROLE_KEY` متاح تلقائياً للدوال ولا يغادر الخادم.
- تنبيه ميزانية Google Cloud عند 80% من 50$ (D1) يضبطه المالك في حسابه.

## 8. المكتبات (مستقرة ومستخدمة في تطبيقات الشركة قدر الإمكان)
| الغرض | المكتبة | متى |
|---|---|---|
| الترجمة وRTL | `flutter_localizations` + `intl` (ARB، `generate: true`) | أ |
| الحالة | `flutter_riverpod` ^3.4.3 | أ |
| التنقل | `go_router` ^18.0.2 | أ |
| التخزين المحلي | `shared_preferences` ^2.5.6 (مع `dependency_overrides: shared_preferences_android: 2.4.28` كما في lamha لتفادي عطل release) | أ |
| مسار حفظ صور العرض | `path_provider` | ب |
| الصورة | `image_picker` | ب |
| الموقع | `geolocator` | ب |
| فتح الخرائط والروابط | `url_launcher` | ب |
| المشاركة | `share_plus` ^13.3.1 | ج |
| الخلفية | `supabase_flutter` | د (بعد التجريبية) |
| الاشتراك | `purchases_flutter` | د (بعد التجريبية) |

- لا حزم توليد كود (freezed، riverpod_generator) ولا حزمة ضغط صور ولا حزمة لقطات شاشة.
- الخط: Tajawal (رخصة OFL) منسوخ من `apps/lamha/assets/fonts/` مع ملف الرخصة.
- الإصدارات تُثبَّت بـ `flutter pub add` وقت البناء، ويُرفع `pubspec.lock`.

## 9. المجلدات
```
apps/brewlens/
  lib/
    main.dart                 # يقرأ env ويختار التنفيذ ويشغّل التطبيق
    app/                      # app.dart, env.dart, router.dart, theme.dart
    l10n/                     # app_ar.arb (القالب), app_en.arb
    domain/
      models/                 # CoffeeType, AnalysisResult, Usage, Review, Shop, AppFailure
      repositories/           # الواجهات المجردة فقط
    backend/                  # ليس data/: ‏.gitignore الجذري يستثني أي مجلد باسم data
      demo/                   # تنفيذات وضع العرض + بيانات نموذجية
      supabase/               # تنفيذات Supabase (الدفعة د)
    services/                 # location, maps_launcher, share_card, image_source
    features/
      auth/ home/ capture/ result/ shops/ history/ review_detail/ share/ paywall/ settings/
    widgets/                  # demo_banner, usage_counter, score_card, stars, empty_state
  test/                       # وحدات + widget
  assets/fonts/ assets/branding/
  supabase/
    migrations/0001_init.sql
    functions/{analyze,usage,delete_account,revenuecat_webhook}/index.ts
  tool/build_release.sh
```
- حزمة Android وiOS: `com.mytatrayd.brewlens` (D15).

## 10. المنصات والصلاحيات
- **Android:** `INTERNET` في `src/main/AndroidManifest.xml` (لازم لـ release، يُضاف في الدفعة د)، `ACCESS_COARSE_LOCATION` و`ACCESS_FINE_LOCATION`، و`<queries>` لنوايا `https` و`geo` (url_launcher). image_picker لا يحتاج صلاحية كاميرا على أندرويد. التوقيع debug للتجريبية فقط.
- **iOS (لاحقاً):** `NSCameraUsageDescription`، `NSPhotoLibraryUsageDescription`، `NSLocationWhenInUseUsageDescription` مع `InfoPlist.strings` بالعربية والإنجليزية (SPEC §5).
- أسماء التطبيق: «عدسة البُن» بالعربية وBrewLens بالإنجليزية.

## 11. الأمان والخصوصية
- لا أي مفتاح أو سر في الكود أو git؛ `.env` مستثنى في `.gitignore` الجذري. فحص بسيط في CI لاحقاً: `grep` لأنماط `AIza` و`sk_` و`service_role` يفشل إن وجد.
- أقل بيانات: البريد (للمصادقة)، الصور الخاصة، إحداثيات المقهى فقط عندما يضغط المستخدم «حفظ موقعي». لا اسم عرض، لا موقع على التقييم، لا تحليلات أو تتبع خارجي.
- الصور: تخزين خاص، روابط موقّعة قصيرة، تُحذف مع التقييم أو الحساب. المشاركة بالبطاقة المولّدة فقط.
- كل الجداول RLS مفعّل، والحقول الحساسة (`is_subscriber`، `is_reviewer`، `usage_daily`، `app_config`) لا يكتبها العميل.
- الحد يُفرض على الخادم فقط؛ العدّاد في التطبيق للعرض. استثناء: وضع العرض يحاكيه محلياً.
- الدرجة `ai_score` يكتبها العميل عند الحفظ (بقيد 0–10)؛ التقييمات خاصة (D10) فلا فائدة من تزويرها. إن صارت عامة لاحقاً تُحفظ النتيجة من الخادم.

## 12. الاختبارات
- وحدات: تحليل `AnalysisResult.fromJson` (صالح، مرفوض، عقد مخالف)، حد وضع العرض (2 يومياً، 23:59 و00:00 بتوقيت الرياض يوماً مختلفاً، المرفوض لا يُحتسب)، بناء رابط الخرائط (إحداثيات/اسم مرمَّز)، متوسطات المفضلة.
- widget: RTL بالعربية وLTR بالإنجليزية، شريط وضع العرض، redirect بلا جلسة، تحويل `AppFailure` إلى النص الصحيح، ملاحظة V60/فرنش بريس، كلمة «تقييم المظهر».
- الخادم (الدفعة د): سكربت SQL لاختبار RLS بمستخدمين (أ) و(ب)، واختبار تزامن `reserve_analysis`.

## 13. خطة البناء للتجريبية (APK أندرويد بوضع العرض، نحو ساعة)
**الدفعة أ — الأساس والهوية وRTL والحساب ووضع العرض (F1، F2 بالعرض)**
- `flutter create --org com.mytatrayd --project-name brewlens --platforms android,ios .` ثم ضبط `applicationId`/`namespace` إلى `com.mytatrayd.brewlens` واسم التطبيق.
- pubspec (مكتبات «أ»)، `l10n.yaml` (قالب `app_ar.arb`)، الثيم (بني القهوة والكريمي، Tajawal)، أيقونة مبدئية.
- `env.dart`، الواجهات الست، تنفيذات Demo لـ Auth، `DemoBanner`، go_router مع redirect.
- شاشات: الدخول، التسجيل، نسيت كلمة المرور (في العرض: رسالة «أُرسل الرابط» شكلية)، رئيسية مبدئية بالعدّاد.
- اختبارات: RTL/LTR، الشريط، redirect. `flutter analyze` و`flutter test` نظيفان.

**الدفعة ب — الكاميرا والتحليل والنتيجة والمقهى والسجل والمفضلة (F5، F6، F7)**
- تنفيذات Demo لـ Analysis (حد الرياض محلياً) وReviews (path_provider) وShops (5 مقاهٍ نموذجية).
- الكاميرا/المعرض، النتيجة (درجة المظهر، التقرير، النجوم، الملاحظات، المقهى، حفظ، مفضلة)، اختيار المقهى (اسم + حفظ موقعي)، السجل (دفعات 20) والمفضلة (متوسطات + فتح خرائط جوجل)، تفاصيل التقييم (تعديل/حذف).
- حالات الخطأ: رفض الصلاحيات، صورة مرفوضة («لم تُحتسب»)، انتهاء الحد → `/paywall` (شاشة مبدئية).
- اختبارات الوحدات في §12 الخاصة بهذه الميزات.

**الدفعة ج — المشاركة والاشتراك والإعدادات وحذف الحساب + GitHub Actions (F8، F9، F10 بالعرض)**
- بطاقة المشاركة وshare_plus. شاشة الاشتراك الكاملة (أسعار D8، تجربة السنوي، الشروط، استعادة) مع `DemoPurchasesRepository`، ومفتاح «محاكاة مشترك» في الإعدادات (وضع العرض فقط).
- الإعدادات: اللغة (فوري ودائم)، الخصوصية/الشروط (روابط placeholder ثابتة في ملف واحد حتى ينشرها المالك)، الخروج، حذف الحساب بتأكيد ثانٍ.
- سير العمل `/.github/workflows/brewlens-android.yml` على نمط `mawid-android.yml`:
  - `on.push.paths: ['apps/brewlens/**', '.github/workflows/brewlens-android.yml']` + `workflow_dispatch`، `permissions: contents: read`.
  - `working-directory: apps/brewlens`، Java temurin 17، `subosito/flutter-action@v2` (stable، cache).
  - `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --release --build-number=${{ github.run_number }}` **بدون أي `--dart-define`** (= وضع العرض، موقّع debug).
  - `actions/upload-artifact@v4` باسم `brewlens-test-apk-${{ github.run_number }}` للملف `apps/brewlens/build/app/outputs/flutter-apk/app-release.apk`. لا أسرار ولا نشر.
  - يُضاف هذا الملف فقط بعد وجود مشروع Flutter فعلي في المجلد (وإلا يفشل على كل push).
- التسليم: نجاح السير على GitHub وتنزيل الـ APK، وتحديث STATUS.md. لا يُقال «يعمل» قبل تثبيته وفتحه فعلاً.

**بعد التجريبية (الدفعة د وما بعدها)**
- كتابة `supabase/migrations/0001_init.sql` و`supabase/functions/*` حسب §7، ثم النشر على مشروع Supabase يملكه المالك (يحتاج موافقته وحسابه، D3) واختبار RLS والتزامن والحد.
- تنفيذات Supabase للواجهات، `supabase_flutter`، صلاحية `INTERNET`، `tool/build_release.sh`.
- RevenueCat (`purchases_flutter`) والمنتجات في المتجرين وwebhook.
- iOS: Info.plist المترجم، سير `brewlens-ios.yml`، الاختبار على جهاز.
- سياسة الخصوصية المنشورة، توقيع الإصدار، الاختبار المغلق (D12).
