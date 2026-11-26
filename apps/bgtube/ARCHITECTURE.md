# ARCHITECTURE — BGTube

أندرويد فقط (MVP). Flutter بدون Firebase؛ كل التخزين محلي على الجهاز (انظر DECISIONS.md: D1، D2).

## الحزم (مستقرة ومشهورة فقط؛ تُثبَّت إصداراتها عند أول `pub get` وتُراجع قبل الاعتماد)
| الغرض | الحزمة |
|---|---|
| التشغيل | `just_audio` (المحرك، يدعم السرعة مع حفظ النغمة) |
| الخلفية والإشعار وشاشة القفل | `audio_service` (خدمة مقدّمة + MediaSession) |
| مقاطعات الصوت (مكالمة/تطبيق آخر) | `audio_session` |
| استخراج الصوت (غير رسمي) | `youtube_explode_dart` خلف واجهة (D4) |
| تسجيل الدخول الرسمي | `google_sign_in` |
| طلبات الشبكة | `http` (عميل قابل للحقن؛ بدل `dio`، D29) |
| الحالة | `flutter_riverpod` |
| التنقل | `go_router` |
| قاعدة محلية | `drift` (SQLite) + `sqlite3_flutter_libs` |
| الإعدادات البسيطة | `shared_preferences` |
| التخزين الآمن | `flutter_secure_storage` (Keystore) |
| المفاتيح من .env | `flutter_dotenv` (D6) |
| المشاركة من يوتيوب | `receive_sharing_intent` (يُتحقق من صيانتها قبل الاعتماد؛ البديل MethodChannel بسيط) |
| اللغة | `flutter_localizations` + `intl` (ملفات ARB: ar أولاً ثم en) |
| الاختبار | `flutter_test`, `mocktail`, `drift` في الذاكرة |

## هيكل المجلدات
```
apps/bgtube/
  .env.example        قالب بدون قيم (الحقيقي .env مستثنى من git)
  lib/
    main.dart, app.dart
    core/             ثوابت، ثيم داكن، أخطاء موحّدة (AppFailure)، أدوات
    l10n/             app_ar.arb, app_en.arb
    domain/           نماذج صرفة وواجهات (لا تعتمد على أي حزمة خارجية)
      models/         Video, Playlist, Channel, PlaybackPosition
      ports/          AudioSourceResolver, AuthService, YouTubeApi, PlaybackQueue, QueueRepository, LocalPlaylistRepository, ...
    data/
      extractor/      تنفيذ AudioSourceResolver (الوحيد الذي يعرف youtube_explode)
      auth/           تنفيذ AuthService (google_sign_in + التخزين الآمن)
      youtube_api/    عميل Data API v3 + الذاكرة المؤقتة + عدّاد الحصة
      local/          drift: favorites, history, positions, api_cache, quota, queue, local_playlists
    audio/            AudioHandler (audio_service) + مؤقت النوم + حفظ الموضع
    features/         player, search, library, playlists, subscriptions,
                      favorites, history, settings, login, queue, local_playlists   (شاشة + مزوّد حالة لكل ميزة)
  test/               مرآة lib/ ؛ unit + widget
  android/            AndroidManifest: INTERNET, FOREGROUND_SERVICE(+MEDIA_PLAYBACK), WAKE_LOCK, intent-filter للمشاركة
```
قاعدة الاعتماد: `features` و`audio` تعتمد على `domain` فقط؛ `data` تنفّذ `domain`؛ الربط في مزوّدات Riverpod عند `app.dart`.

## عزل الاستخراج (الأهم)
- واجهة واحدة `AudioSourceResolver`: مدخلها `videoId` فقط (نص)، ومخرجها `ResolvedAudio { url, انتهاء الصلاحية, مدة, عنوان }` أو `AppFailure`.
- لا تستقبل أي رمز دخول أو كوكي أو معرّف حساب، ولا يُمرَّر لها `AuthService`. هذا يُفرَض بالتصميم (التوقيع) وباختبار يتأكد أن التنفيذ لا يعتمد على طبقة auth.
- المعالج الصوتي يطلب الرابط عند كل تشغيل، ويعيد الطلب تلقائياً مرة عند انتهاء الرابط؛ الفشل يظهر رسالة عربية + "إعادة المحاولة".
- الاستبدال (مثلاً yt-dlp أو خدمة أخرى) = تنفيذ جديد للواجهة وتغيير سطر ربط واحد.

## الحساب وYouTube Data API v3
- الدخول عبر `google_sign_in` الرسمي (شاشة جوجل؛ لا نلمس كلمة المرور). الإصدار 7.x: التفويض فقط عبر `authorizationClient` بعميل Android وبلا serverClientId (D23). النطاقات: `youtube.readonly` للقراءة، و`youtube` فقط لعمليات الكتابة (إعجاب، إضافة/حذف من قائمة). تُطلب الكتابة عند أول استخدام فقط.
- `AuthService`: `signIn`, `signOut`, `getAccessToken` (يُجدَّد عبر Play Services)، حالة `Stream`. مشروع OAuth في In production بدون توثيق (D7) فلا انتهاء أسبوعي؛ تجديد صامت عبر Play Services. السحب أو الإبطال → `AuthExpired` → رسالة "سجّل الدخول من جديد".
- `YouTubeApi` (منفذ في domain) ينفّذه `YouTubeDataApi` في `data/youtube_api` فوق `http.Client` محقون؛ يطلب الرمز من `AuthService` لكل طلب ويضعه في ترويسة Authorization فقط (لا مفتاح API)، و401 يُبطل الرمز ويعيد مرة ثم `AuthExpired`. كل الطلبات من التطبيق مباشرة (لا خادم وسيط). التفاصيل والتكلفة في D29.
- تكلفة الحصة (10,000/يوم): `search.list` ≈ 100؛ القراءات (`playlists`, `playlistItems`, `subscriptions`, `videos.list?myRating=like`, `videos`) = 1؛ الكتابة (`videos.rate`, `playlistItems.insert/delete`) ≈ 50.
  - فيديوهات قناة: عبر قائمة الرفع (`playlistItems`، 1 وحدة) بدل البحث (100).
  - تفاصيل المدة تُجلب دفعة واحدة `videos.list` (حتى 50 معرّفاً).
  - `fields=` لأقل الحقول، و`maxResults` معتدل.
- الذاكرة المؤقتة (جدول `api_cache` بمفتاح = الطلب المطبَّع): مدة صلاحية: بحث 6 ساعات، قوائم/إعجابات/اشتراكات 15 دقيقة، تفاصيل فيديو 24 ساعة؛ يُبطَل مباشرة بعد أي عملية كتابة على المورد نفسه. التحديث يدوي (سحب للتحديث)، لا تحديث تلقائي.
- عدّاد الحصة: جدول `quota` يجمع التكلفة التقديرية لليوم (يُصفَّر عند منتصف الليل بتوقيت المحيط الهادئ). عند تجاوز 95% أو عند ردّ 403 `quotaExceeded`: تظهر "انتهت حصة البحث اليوم" ويُخدَم المخزَّن فقط.
- التزامن: الكتابة تتم فوراً على يوتيوب ثم يُبطَل الكاش. السجل والمفضلة محليان فقط (D5).

## التخزين الآمن للرموز
- لا نحفظ رمز وصول طويل الأمد بأنفسنا: Play Services يدير الجلسة ويصدر رموز وصول قصيرة العمر عند الطلب.
- `flutter_secure_storage` (Android Keystore) لما نحتاجه فقط: علامة "توجد جلسة" وحدها (لا بريد ولا اسم ولا رموز، D23). `signOut` يمسحها ويمسح `api_cache` للبيانات الخاصة (عند بناء طبقة API).
- قاعدة: `data/auth` لا يستورده إلا `main.dart` وطبقة `data/youtube_api`؛ و`data/youtube_api` لا يستورده إلا `main.dart` ويستعمل منفذ `AuthService` لا تنفيذه؛ المستخرج وطبقة الصوت لا يعرفان auth ولا الواجهة (اختبار معماري).
- ممنوع: تسجيل الرموز في السجلات، أو وضعها في shared_preferences/drift/ملفات، أو إرسالها لغير `googleapis.com`.
- `android:allowBackup="false"` لمنع نسخ البيانات للسحابة.

## الصوت والخلفية
- `AudioHandler` يمتد من `BaseAudioHandler` ويلفّ `just_audio`؛ إشعار تحكم + شاشة قفل (تشغيل/إيقاف/التالي/السابق).
- `audio_session` بإعداد "music/speech": إيقاف مؤقت عند مكالمة، واستئناف بعدها؛ خفض الصوت عند إشعارات قصيرة.
- السرعة 0.75–2 عبر `setSpeed` (نغمة ثابتة)، وتُحفظ لكل تشغيل لاحق في الإعدادات.
- مؤقت النوم (15/30/60): مؤقت داخل المعالج (لا في واجهة المستخدم) يخفّض الصوت تدريجياً ثم يوقف؛ يعرض الوقت المتبقي عبر Stream.
- حفظ الموضع: كل ~5 ثوانٍ وعند الإيقاف/الخروج، في جدول `positions`؛ لا يُحفظ إن كانت المشاهدة < 10 ثوانٍ؛ يُحذف عند الاقتراب من النهاية.
- الطابور (الميزة 10، التفاصيل في D27):
  - النموذج صرف في domain: `VideoRef` و`QueueEntry{key, ref, failed}` و`QueueSnapshot{entries, currentKey}`. عملياته في `playback_queue_model.dart`، ونتتبّع الحالي بمفتاحه لا بفهرسه.
  - منفذ واحد للإضافة والتحكم هو `PlaybackQueue`: `enqueue(refs, playNow|playNext|addToEnd)` والتالي والسابق و`jumpTo` و`removeEntry` و`moveEntry` و`clearUpcoming`. تنفّذه `BgtubeAudioHandler`، وكل الشاشات تضيف عبره فقط، و`playVideo` غلاف له.
  - المشغّل بمصدر واحد في كل لحظة (لا playlist في just_audio). المعالج ينشر `queue` و`mediaItem` و`queueIndex` في audio_service، ويعيد تعريف skipToNext/Previous/QueueItem. "السابق" بعد ٣ ث يعيد المقطع من بدايته.
  - استخراج كسول للحالي، وللتالي بعد جاهزية الحالي فقط، في ذاكرة من عنصرين مع هامش انتهاء ١٠ د.
  - الفاشل نهائياً يُعلَّم ويُتخطّى. يتوقف الطابور مع "إعادة المحاولة" عند `network` أو بعد ٣ فشلات متتالية.
  - الأحدث يفوز عبر `_token`. مؤقت النوم يستمر عبر المقاطع، وانتهاؤه `pause` فيتوقف الطابور. السرعة تُطبَّق على كل عنصر.
  - الحفظ لقطة كاملة في drift عند كل تغيير. الاستعادة عند الإقلاع بلا استخراج ولا تشغيل، وأول `play()` يحمّل الحالي من `positions`.
- بطارية: تنبيه إرشادي لاستثناء التطبيق من تحسين البطارية.

## نموذج البيانات المحلي (drift)
- `favorites(videoId PK, title, channel, thumbUrl, durationSec, addedAt)`
- `history(id PK, videoId, title, channel, thumbUrl, playedAt)` — حد أقصى 500 سجل.
- `positions(videoId PK, positionMs, durationMs, updatedAt)`
- `api_cache(key PK, json, fetchedAt, ttlSec, private)` و`quota(dayPt PK, units)` (v3، D29).
- `queue_entries(key PK, ord, videoId, title?, author?, durationMs?, thumbUrl?, failed)`، و`queue_state(id=0 PK, currentKey?, updatedAt)`. موضع الحالي مصدره `positions` وحده.
- `local_playlists(id PK auto, name 1..100, createdAt, updatedAt)`، و`local_playlist_items(playlistId FK cascade, ord, videoId, title?, author?, durationMs?, thumbUrl?, PK(playlistId, ord))`. محلية فقط ولا تُرسل إلى يوتيوب.
- الإصدارات: v1 = `positions`، وv2 تضيف جداول الطابور والقوائم المحلية (`onUpgrade from<2`، و`PRAGMA foreign_keys=ON` في beforeOpen). المخططات تُصدَّر إلى `drift_schemas/` مع اختبارات ترحيل مولَّدة.
- الإعدادات (shared_preferences): اللغة، السرعة، آخر مؤقت.

## الأمان والخصوصية
- لا مفاتيح في الكود ولا في git. `.env` (مستثنى في .gitignore الجذري) يحوي عند الحاجة فقط (لا شيء الآن، D22): `GOOGLE_OAUTH_CLIENT_ID` (عميل ويب، غير موجود وغير مطلوب لمسار التفويض) و`YOUTUBE_API_KEY` للطلبات العامة إن اخترنا ذلك. يُنشأ `.env.example` بأسماء فقط. تنبيه صريح: ما يُحزَّم في APK يمكن استخراجه؛ لذلك مفتاح API يُقيَّد في Google Cloud باسم الحزمة وبصمة SHA-1، ولا نعدّه سرّاً قوياً. بدون أي مفتاح يعمل التطبيق بوضع تجريبي (لصق رابط وتشغيل فقط).
- OAuth client من نوع Android مربوط باسم الحزمة وبصمة التوقيع (لا يحوي سرّاً).
- أقل بيانات: لا Firebase ولا تحليلات ولا تقارير أعطال خارجية ولا إعلانات. لا شيء يغادر الجهاز إلا طلبات googleapis.com ومحتوى يوتيوب.
- كل HTTPS؛ لا `usesCleartextTraffic`.
- مسح كامل عند تسجيل الخروج للبيانات الخاصة.

## الاختبارات
- Unit: محلّل الروابط (watch/youtu.be/shorts/playlist/غير صالح)، سياسة الكاش وTTL والإبطال، عدّاد الحصة وإعادة التصفير، مؤقت النوم (بساعة وهمية)، قاعدة حفظ الموضع (<10 ثوانٍ)، تحويل ردود API إلى النماذج (JSON ثابتة).
- Unit: `YouTubeDataApi` مع `MockClient` من `package:http/testing.dart` وdrift في الذاكرة (401 → AuthExpired، 403 quota → رسالة الحصة، الكاش وTTL، الحصة بيوم المحيط الهادئ).
- اختبار معماري: لا استيراد من `data/extractor` خارج ربط المزوّدات، ولا يعتمد التنفيذ على `auth`.
- Widget: الشاشات بالعربية RTL (لا overflow)، الحالات الفارغة والخطأ و"إعادة المحاولة"، مع تنفيذات وهمية للمنافذ.
- drift في الذاكرة لاختبار المستودعات، واختبار ترحيل المخطط (v1→v2 يحفظ `positions`).
- الطابور: وحدات للنموذج الصرف، والمعالج بمشغّل وهمي يغطي الانتقال التلقائي وسباق الضغط على "التالي" وتخطّي الفاشل وحدوده، وأنه لا يستخرج غير الحالي والتالي في طابور من ٢٠٠، وانتهاء الرابط، ومؤقت النوم والسرعة عبر الانتقالات. اختبار معماري: audio_service داخل `lib/audio` فقط.
- يدوي على جهاز حقيقي (لا يغطيه الآلي): شاشة مغلقة 10 دقائق، مكالمة، إشعار/قفل، مشاركة من يوتيوب، طابور من ٣ مقاطع بشاشة مغلقة مع التالي/السابق من الإشعار وشاشة القفل، قتل التطبيق ثم استئناف الطابور، تزامن الإعجاب خلال دقيقة، انتهاء رمز الدخول، قتل البطارية للخدمة.
- أوامر الجودة: `flutter analyze` و`flutter test` بلا أخطاء قبل أي تسليم.
