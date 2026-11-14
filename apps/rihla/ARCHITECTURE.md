# ARCHITECTURE — رحلة (rihla)

الحالة: تصميم قبل البناء (2026-11-14). لا كود بعد. القرارات وأسبابها في DECISIONS.md.

## 1. نظرة عامة
- Flutter (iOS + Android) بلا خلفية سحابية في MVP: لا Firebase، لا حسابات، لا رفع. كل البيانات على الجوال.
- الأفقي فقط. شاشة مقسومة: يسار كاميرا، يمين خريطة.
- الفيديو المزدوج يُركَّب وقت التسجيل داخل إضافة أصلية (native plugin) تملك الكاميرا والترميز. الخريطة رسم Flutter (flutter_map) تُلتقط إطاراتها وتُرسل للمُركِّب.
- الخريطة داخل الفيديو ليست خريطة جوجل (انظر القسم 4 وDECISIONS D3). خرائط جوجل تُستعمل فقط لرابط مشاركة المسار.

## 2. الحزم (مستقرة ومشهورة فقط)
| الغرض | الحزمة |
|---|---|
| الحالة | flutter_riverpod |
| التنقل | go_router |
| الموقع | geolocator |
| الأذونات | permission_handler |
| الخريطة (رسم Flutter) | flutter_map + latlong2 |
| قاعدة البيانات المحلية | drift + sqlite3_flutter_libs (+ drift_dev, build_runner) |
| الحفظ في المعرض | gal |
| المشاركة | share_plus |
| فتح الروابط/الإعدادات | url_launcher (+ openAppSettings من permission_handler) |
| بقاء الشاشة مضاءة | wakelock_plus |
| المسارات/الملفات | path_provider |
| اللغات | flutter_localizations + intl (ARB) |
| الاختبار | flutter_test، integration_test، mocktail |
- لا ffmpeg_kit (أُوقف مشروعه وأُزيلت ملفاته الثنائية في 2025). لا Firebase Crashlytics/Analytics (خصوصية).
- الإضافة الأصلية داخل المشروع نفسه (plugin محلي في packages/rihla_recorder): Kotlin (CameraX + OpenGL ES + MediaCodec/MediaMuxer) وSwift (AVCaptureSession + AVAssetWriter + CoreImage/Metal).

## 3. هيكل المجلدات
```
lib/
  main.dart, app.dart            # ProviderScope، MaterialApp.router، اللغة والاتجاه
  core/
    config/env.dart              # String.fromEnvironment (مفاتيح من --dart-define-from-file)
    geo/ (simplify.dart, distance.dart, gpx.dart, maps_link.dart)  # دوال نقية قابلة للاختبار
    utils/ (formatters, storage_estimate)
  data/
    db/ (app_database.dart: Trips, TrackPoints)
    repositories/ trip_repository.dart
    platform/ recorder_channel.dart   # MethodChannel/EventChannel + Texture
  domain/ trip.dart, track_point.dart, recording_state.dart
  features/
    onboarding_permissions/      # F2
    recording/                   # F1,F3,F4,F5,F6,F7 (شاشة، مُتحكِّم، رسم الخريطة والالتقاط)
    summary/                     # ملخص ما بعد الرحلة
    history/                     # F8 (قائمة، تفاصيل، حذف)
    share/                       # F9
    settings/                    # جودة، لغة، إخلاء مسؤولية
  l10n/ app_ar.arb, app_en.arb
packages/rihla_recorder/         # الإضافة الأصلية android/ ios/ + واجهة Dart
test/ integration_test/
```
قاعدة: features لا تستدعي القنوات الأصلية مباشرة؛ فقط عبر data/platform.

## 4. تدفق الفيديو المزدوج (الخطر الأكبر)
1. الإضافة الأصلية تفتح الكاميرا الخلفية (16:9، 30fps) وتعرض المعاينة للـFlutter كـTexture (الجهة اليسرى).
2. الجهة اليمنى: ويدجت خريطة flutter_map داخل RepaintBoundary بنسبة 1:1.125 (نصف لوحة 16:9: 640x720 لـ720p، 960x1080 لـ1080p).
3. المتحكّم يلتقط RepaintBoundary.toImage بمعدل 5 إطارات/ث (قابل للضبط) ويرسل البايتات الخام (RGBA) للإضافة عبر قناة ثنائية؛ يُحتفَظ بآخر إطار ويُكرَّر.
4. الإضافة تركّب في كل إطار كاميرا: اللوحة 16:9 = كاميرا (قص مركزي) يسار + آخر إطار خريطة يمين، وترمّزه H.264 مع صوت AAC من الميكروفون بنفس ساعة الإطار الزمنية (تزامن الصوت).
5. الكتم: الإضافة تكتب صمتاً (عينات صفرية) فتبقى المدة متطابقة.
6. الإيقاف: تُغلق الملف ثم gal يحفظه في المعرض، ثم يُسجَّل المسار.
- iOS: movieFragmentInterval (مثلاً 10 ث) ليبقى الملف قابلاً للاسترداد عند القتل المفاجئ. أندرويد: التحقق في النموذج التجريبي (مقاطع قصيرة تُدمج عند الإنهاء إن لزم).
- الحرارة: iOS ProcessInfo.thermalState، أندرويد PowerManager thermal status؛ تحذير ثم خفض إلى 720p/خفض معدل إطارات الخريطة.
- بوابة قبول (قبل بناء بقية التطبيق): نموذج تجريبي على جهازين حقيقيين، 30 دقيقة، 720p ثم 1080p: بلا تجمد، حرارة مقبولة، فقدان إطارات < 1%، انحراف صوت < 100ms، يفتح في مشغل الجوال.
- بدائل بالترتيب إن فشل: (ج) تسجيل كاميرا وخريطة كملفين ثم دمج أصلي بعد الرحلة (AVMutableComposition / Media3 Transformer)، ثم (أ) تسجيل شاشة النظام (ReplayKit / MediaProjection، يتطلب نافذة إذن كل مرة ويلتقط عناصر الواجهة). السبب في DECISIONS D2.

### الخريطة وشروط جوجل (خلاصة)
- لا يوجد في الشروط التي وجدتها نصٌّ يسمح صراحةً بتسجيل خريطة جوجل داخل فيديو يوزّعه ويشاركه المستخدمون. إرشادات جوجل لاستخدام الخرائط في الفيديو تشترط الالتزام بها، والفيديو الترويجي بشروط ضيقة (≤30 ث، بلا Street View، للترويج لتطبيقك فقط) وتُمنع النسخ والتخزين غير المصرّح به. فيديو يشاركه المستخدمون على نطاق واسع غير مغطى. لذا الافتراض: غير مسموح، فنستخدم خريطة بديلة داخل الفيديو.
- المصادر: [Google Geo Guidelines](https://about.google/brand-resource-center/products-and-services/geo-guidelines/)، [Google Maps Platform Service Specific Terms](https://cloud.google.com/maps-platform/terms/maps-service-terms/index-20240522)، [Map Tiles API Policies](https://developers.google.com/maps/documentation/tile/policies).
- قبل الإطلاق: مراجعة قانونية/كتابية لصفحة الشروط الحالية؛ إن أراد المالك خريطة جوجل داخل الفيديو يُرسل طلب إذن كتابي لجوجل (قرار المالك).
- الخريطة البديلة: بلاطات OpenStreetMap عبر مزوّد تجاري/مجاني بشروط تسمح (MapTiler أو Stadia Maps أو Mapbox؛ المقترح MapTiler) مع الإسناد الظاهر داخل الفيديو "© OpenStreetMap contributors © MapTiler". لا نستخدم tile.openstreetmap.org مباشرة (سياستهم تمنع الاستخدام الكثيف في التطبيقات).
- تحقق قبل الاعتماد: شروط المزوّد المختار تسمح بحفظ العرض داخل فيديو مشارَك (أشير إليها في SPEC كمطلوب).

## 5. نموذج البيانات (SQLite عبر drift)
- Trips: id (uuid)، startedAt، endedAt، durationSec، distanceM، videoAssetId (معرّف المعرض أو null)، videoPath احتياطي، quality (720/1080)، status (recording | completed | interrupted)، title اختياري.
- TrackPoints: id، tripId (FK, ON DELETE CASCADE)، seq، lat، lng، ts، accuracyM، speedMps اختياري.
- فهرس على (tripId, seq). تُكتب النقاط على دفعات كل ~5 ثوانٍ (حفظ دوري)؛ عند فتح التطبيق أي رحلة status=recording تُعلَّم interrupted وتُعرض.
- تصفية النقاط: تُتجاهل الدقة > 50m وقفزات غير منطقية؛ المسافة تُحسب بـHaversine.
- الفيديو لا يُنسخ داخل التطبيق: يُحفظ في المعرض عبر gal؛ يُخزَّن المعرّف فقط. حذف الرحلة لا يحذف الفيديو إلا بموافقة صريحة منفصلة.
- لا بيانات شخصية: لا حساب، لا تحليلات، لا إرسال. التفضيلات (اللغة، الجودة) في shared_preferences.

## 6. إدارة الحالة
- Riverpod: recordingControllerProvider (Notifier بحالة: idle/preparing/recording/stopping/saved + مدة + مسافة + GPS + كتم + مساحة)، tripsProvider (Stream من drift)، settingsProvider، permissionsProvider.
- الحالة تُحدَّث من تدفقات: Geolocator.getPositionStream، EventChannel من الإضافة (أخطاء/حرارة/مساحة)، مؤقت المدة.
- دورة الحياة (F4): WidgetsBindingObserver؛ عند paused/inactive أثناء التسجيل: stopAndSave فوراً، علامة "أُوقفت وحُفظت" تُعرض عند العودة. المكالمات تُحسّ عبر انقطاع جلسة الصوت/الكاميرا في الإضافة (AVAudioSession interruption / أحداث الكاميرا) وتُبلَّغ للـDart.

## 7. المشاركة والتصدير
- المسار المبسّط: Douglas-Peucker بتحمّل متزايد حتى يصل العدد ≤ N. الرابط: `https://www.google.com/maps/dir/?api=1&origin=..&destination=..&waypoints=p1|p2|..&travelmode=driving` (مرمَّز URL). حد الطول 2048 حرفاً (من توثيق Maps URLs). عدد نقاط المنتصف الافتراضي 3 لأن توثيق Maps URLs (حسب ما أتذكر ولم أستطع التحقق منه آلياً) يحدّه بـ3 على تطبيق الجوال و9 على سطح المكتب؛ يُثبَّت الرقم الفعلي في النموذج التجريبي على آيفون وأندرويد. الرابط يحسب خرائط جوجل مساراً على الطرق، فهو تقريبي بالتصميم ولا يحتاج مفتاح API ولا فوترة.
- يُفتح الرابط: تطبيق خرائط جوجل إن وُجد وإلا المتصفح.
- GPX 1.1: ملف يُولَّد نصياً (trk/trkseg/trkpt مع ele اختياري وtime بـUTC) في مجلد مؤقت ويُشارك عبر share_plus (XFile)، ثم يُحذف المؤقت. بلا حزمة خارجية.
- الفيديو: share_plus مع ملف من المعرض؛ تنبيه واتساب قبل المشاركة وتوصية بحد (مثلاً > 3 دقائق أو > 100MB يظهر تحذير؛ الرقم يُضبط بالتجربة).

## 8. الأمان والخصوصية
- لا مفاتيح في الكود أو git. مفتاح مزوّد البلاطات فقط (MAPTILER_KEY) في `.env` مستثنى من git ويُمرَّر بـ `--dart-define-from-file=.env`. المالك يضعه بيده؛ ملف `.env.example` فارغ القيم مرفق. تنبيه صريح: أي مفتاح داخل تطبيق عميل قابل للاستخراج من الحزمة؛ لذلك يُقيَّد عند المزوّد (النطاق/الحزمة إن أمكن) ويوضع سقف استخدام وتنبيه. إن أسيء استخدامه: وسيط (proxy) خفيف لاحقاً.
- لا حاجة لمفتاح جوجل أصلاً (رابط مشاركة فقط).
- قواعد Firebase: غير مطلوبة (لا Firebase). إن أُضيفت سحابة لاحقاً: Firestore rules مغلقة افتراضياً مع request.auth.uid == userId، وApp Check. مدوّن للمستقبل فقط.
- ملف الأذونات: iOS Info.plist (NSCameraUsageDescription، NSMicrophoneUsageDescription، NSLocationWhenInUseUsageDescription، NSPhotoLibraryAddUsageDescription) بنص عربي/إنجليزي؛ أندرويد: CAMERA، RECORD_AUDIO، ACCESS_FINE_LOCATION، لا قراءة تخزين. لا أذونات خلفية.
- تُمنع النسخ الاحتياطية التلقائية لقاعدة المسارات (allowBackup=false) حفاظاً على الخصوصية، ما لم يقرر المالك غير ذلك.
- سياسة خصوصية (مطلوبة للمتاجر): "لا نجمع ولا نرسل أي بيانات". إخلاء مسؤولية داخل التطبيق: تسجيل الأشخاص/الصوت في السيارة وقوانين المرور بحمل الجوال (يُراجع نصه مختص).
- طلبات الشبكة الوحيدة: بلاطات الخريطة (تكشف تقريباً موقع المستخدم للمزوّد؛ يُذكر في سياسة الخصوصية).

## 9. المساحة والبطارية
- معدلات تقريبية: 720p ≈ 4Mbps ≈ 300MB/10د؛ 1080p ≈ 8Mbps ≈ 600MB/10د (تُقاس في النموذج).
- تنبيه عند < 1GB متاحة، إيقاف وحفظ تلقائي عند < 300MB. تنبيه بطارية < 15% وإن لم تكن موصولة. (الأرقام ثوابت في core/config.)
- بلا شبكة: البلاطات المخزّنة تبقى، والباقي رمادي برسالة "الخريطة تحتاج إنترنت"؛ الفيديو والمسار يستمران. (الرمادي يظهر في الفيديو أيضاً: مقبول في MVP.)

## 10. خطة الاختبار
- وحدات (CI): simplify، haversine، gpx (مقارنة مع XSD GPX 1.1)، maps_link (طول ≤ 2048، عدد النقاط)، تقدير الحجم، منطق المساحة، مستودع drift في الذاكرة، مُتحكِّم التسجيل بقناة مزيّفة (mocktail).
- ويدجت: شاشة الأذونات (قبول/رفض/فتح الإعدادات)، RTL/LTR بلا overflow، السجل، تأكيد الحذف بخيارين.
- تكامل (integration_test) على جهازين حقيقيين: بدء/إيقاف، خروج للخلفية، قفل، مكالمة، قتل التطبيق ثم استرداد الرحلة.
- يدوي (قائمة قبول F7): رحلة 30د على آيفون وأندرويد 720p و1080p؛ فتح الناتج في المعرض؛ تزامن الصوت (تصفيق)؛ فحص حرارة وبطارية؛ تدوير الجوال يمين/يسار؛ مشاركة واتساب؛ فتح الرابط بتطبيق جوجل وفي المتصفح؛ فتح GPX في Strava/أداة GPX ومطابقته؛ رحلة طويلة تتأكد من حد النقاط.
- تُجمع النتائج في TESTERS.md وFEEDBACK.md. لا يُقال "يعمل" قبل تشغيله فعلاً.

## 11. المراحل
1. نموذج تجريبي للدمج (بوابة قبول، أسبوعان تقريباً) + نموذج رابط جوجل/GPX.
2. هيكل Flutter + اللغات + الأذونات + قاعدة البيانات.
3. شاشة التسجيل + الإضافة الأصلية + دورة الحياة.
4. السجل والمشاركة والملخص.
5. اختبارات الأجهزة، سياسة الخصوصية، التجهيز للمتاجر.
