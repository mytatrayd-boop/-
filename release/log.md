# سجل الرفع

| التاريخ (UTC) | التطبيق | المنصة | المسار | run | رقم البناء | النتيجة |
|---|---|---|---|---|---|---|
| 2026-10-24 01:38 | لمحة 1.0.1 | Android | alpha | 40050683818 | 3 | فشل في خطوة Upload to Google Play: "The caller does not have permission" (البناء والتوقيع نجحا، artifact lamha-aab-3). يحتاج صلاحية حساب الخدمة في Play Console. |
| 2026-10-24 | لمحة 1.0.1 | Android | alpha | 40055114955 | 4 | إعادة محاولة بطلب المنسق: نفس الفشل في Upload to Google Play "The caller does not have permission" (البناء نجح، artifact lamha-aab-4). لا تكرار حتى تُمنح صلاحية حساب الخدمة على لمحة في Play Console. |
| 2026-10-24 | لمحة 1.0.1 | Android | alpha | 40056689648 | 5 | بعد منح المالك الصلاحية: نفس الفشل "The caller does not have permission" (البناء نجح، artifact lamha-aab-5). انتظار 5 دقائق ثم محاولة أخيرة. |
| 2026-10-24 | لمحة 1.0.1 | Android | alpha | 40057627034 | 6 | المحاولة الأخيرة بعد انتظار 5 دقائق: نفس الفشل "The caller does not have permission" (artifact lamha-aab-6). توقفت؛ يحتاج تحقق المالك من الصلاحية في Play Console. |
| 2026-10-24 | لمحة (صفحة المتجر) | Google Play | dry-run | 40058591359 | — | فشل 403 عند validate (حساب الخدمة بلا صلاحية كافية على sa.lamha.lamha). لم يُكرر ولم يُشغّل apply. |
| 2026-10-24 | لمحة (صفحة المتجر) | App Store | dry-run | 40058591359 | — | نجح. |
| 2026-10-24 | لمحة (صفحة المتجر) | App Store | apply + build 8 | 40058701314 | 8 | نجح: النصوص واللقطات وملاحظات المراجع، وربط build 8. لم يُرسل للمراجعة. تحذير: التصنيف العمري لم يُحدَّث (409، أبل تطلب الحقل ageAssurance غير الموجود في age_rating.json). |
| 2026-10-24 | لمحة (صفحة المتجر) | App Store | apply + build 8 | 40060109983 | 8 | فشل قبل الوصول للتصنيف العمري: PATCH appStoreReviewDetails -> 409 ENTITY_ERROR.ATTRIBUTE.REQUIRED (contactFirstName, contactLastName، والرسالة مقطوعة بعدها). أسرار ASC_REVIEW_* غير مضافة على الأرجح. لم يُرسل للمراجعة. |
| 2026-10-24 | لمحة (صفحة المتجر) | App Store | apply + build 8 | 40060235070 | 8 | نجح التشغيل (الصفحة وملاحظات المراجع وربط build 8 بلا تحذير). التصنيف العمري لم يُحدَّث: 409 ENTITY_ERROR.ATTRIBUTE.REQUIRED للحقلين messagingAndChat وadvertising (الرسالة مقطوعة). لم يُرسل للمراجعة. |
| 2026-10-24 | لمحة (صفحة المتجر) | App Store | apply + build 8 | 40062366810 | 8 | نجح التشغيل بلا أخطاء غير التصنيف العمري: 409 ينقصه gunsOrOtherWeapons وparentalControls وuserGeneratedContent وhealthOrWellnessTopics. لم يُرسل للمراجعة. |
| 2026-10-24 | لمحة (صفحة المتجر) | App Store | apply + build 8 | 40063900063 | 8 | نجح بلا أي تحذير: قبلت أبل التصنيف العمري وبقية الصفحة وربط build 8. لم يُرسل للمراجعة. |
| 2026-10-24 | لمحة (صفحة المتجر) | Google Play | dry-run | 40070651787 | — | نجح بلا تحذيرات. |
| 2026-10-24 | لمحة (صفحة المتجر) | Google Play | apply | 40070711242 | — | نجح بلا تحذيرات. |
| 2026-10-24 | لمحة 1.0.1 | Android | alpha | 40070770259 | 7 | نجح: رُفع الإصدار 7 إلى alpha بحالة completed (artifact lamha-aab-7). |
